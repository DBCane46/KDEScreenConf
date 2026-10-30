mod modifiers;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::{
    collections::BTreeMap,
    fs,
    path::PathBuf,
    process::Command,
    sync::{Arc, Mutex},
    thread,
    time::{Duration, Instant},
};
const BUS: &str = "org.kde.KDEScreenConf";
const PATH: &str = "/KDEScreenConf";
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
struct Monitor {
    name: String,
    identity: String,
    width: u64,
    height: u64,
    internal: bool,
}
#[derive(Clone, Serialize, Deserialize)]
struct Assignment {
    monitor: String,
    zone: usize,
}
#[derive(Clone, Serialize, Deserialize, Default)]
struct Profile {
    name: String,
    #[serde(default)]
    applications: BTreeMap<String, Assignment>,
    layouts: BTreeMap<String, String>,
    #[serde(default)]
    custom: BTreeMap<String, Vec<[f64; 4]>>,
}
#[derive(Clone, Serialize, Deserialize)]
struct Config {
    version: u32,
    #[serde(default = "default_gap")]
    gap: u32,
    automatic: bool,
    #[serde(default = "enabled")]
    drag_overlay: bool,
    #[serde(default = "enabled")]
    placement_helper: bool,
    profiles: BTreeMap<String, Profile>,
}
fn default_gap() -> u32 {
    2
}
fn enabled() -> bool {
    true
}
impl Default for Config {
    fn default() -> Self {
        Self {
            version: 1,
            gap: default_gap(),
            automatic: true,
            drag_overlay: true,
            placement_helper: true,
            profiles: BTreeMap::new(),
        }
    }
}
struct State {
    config: Config,
    monitors: Vec<Monitor>,
    key: String,
    error: String,
    path: PathBuf,
    identify: Option<(String, Instant)>,
    desktop_id: String,
    desktop_name: String,
    free_move: bool,
    modifier_at: u64,
    modifier_ready: bool,
}
fn profile_key(monitors: &[Monitor]) -> String {
    let mut ids: Vec<_> = monitors.iter().map(|m| m.identity.clone()).collect();
    ids.sort();
    serde_json::to_string(&ids).unwrap()
}
fn classify(ms: &[Monitor]) -> &'static str {
    let internal = ms.iter().filter(|m| m.internal).count();
    let external: Vec<_> = ms.iter().filter(|m| !m.internal).collect();
    match (internal, external.len()) {
        (1, 0) => "Mobile",
        (1, 1) => "Wide desk",
        (1, 2) => "Dual desk",
        (0, 5)
            if external
                .iter()
                .filter(|m| m.width.max(m.height) >= 3840)
                .count()
                == 3 =>
        {
            "Workstation"
        }
        _ => "Custom setup",
    }
}
fn zones(layout: &str) -> Option<Vec<[f64; 4]>> {
    Some(match layout {
        "full" => vec![[0., 0., 1., 1.]],
        "halves" => vec![[0., 0., 0.5, 1.], [0.5, 0., 0.5, 1.]],
        "thirds" => (0..3).map(|i| [i as f64 / 3., 0., 1. / 3., 1.]).collect(),
        "priority" => vec![
            [0., 0., 0.25, 1.],
            [0.25, 0., 0.5, 1.],
            [0.75, 0., 0.25, 1.],
        ],
        "left-stack" => vec![[0., 0., 0.5, 1.], [0.5, 0., 0.5, 0.5], [0.5, 0.5, 0.5, 0.5]],
        "quarters" => vec![
            [0., 0., 0.5, 0.5],
            [0.5, 0., 0.5, 0.5],
            [0., 0.5, 0.5, 0.5],
            [0.5, 0.5, 0.5, 0.5],
        ],
        _ => return None,
    })
}
fn validate_zones(zones: &[[f64; 4]]) -> Result<(), String> {
    if zones.is_empty() || zones.len() > 9 {
        return Err("Use between 1 and 9 zones".into());
    }
    for z in zones {
        if z.iter().any(|n| !n.is_finite())
            || z[0] < 0.
            || z[1] < 0.
            || z[2] < 0.05
            || z[3] < 0.05
            || z[0] + z[2] > 1.000001
            || z[1] + z[3] > 1.000001
        {
            return Err(
                "Zones must stay inside the screen and be at least 5% wide and high".into(),
            );
        }
    }
    for (i, a) in zones.iter().enumerate() {
        for (j, b) in zones.iter().enumerate().skip(i + 1) {
            let width = (a[0] + a[2]).min(b[0] + b[2]) - a[0].max(b[0]);
            let height = (a[1] + a[3]).min(b[1] + b[3]) - a[1].max(b[1]);
            if width > 1e-9 && height > 1e-9 {
                return Err(format!("Zones {} and {} overlap", i + 1, j + 1));
            }
        }
    }
    Ok(())
}
fn parse_monitors(
    v: &Value,
    identities: &BTreeMap<String, String>,
) -> Result<Vec<Monitor>, String> {
    let outputs = v["outputs"].as_array().ok_or("Missing outputs")?;
    let mut ms = Vec::new();
    for o in outputs {
        if o["connected"] != true || o["enabled"] != true {
            continue;
        }
        let name = o["name"].as_str().ok_or("Missing output name")?.to_owned();
        let mode = o["modes"]
            .as_array()
            .and_then(|m| m.iter().find(|m| m["id"] == o["currentModeId"]));
        let size = mode.map(|m| &m["size"]).unwrap_or(&o["size"]);
        ms.push(Monitor {
            identity: identities
                .get(&name)
                .cloned()
                .unwrap_or_else(|| format!("connector:{name}")),
            internal: name.starts_with("eDP") || name.starts_with("LVDS"),
            name,
            width: size["width"].as_u64().unwrap_or(0),
            height: size["height"].as_u64().unwrap_or(0),
        });
    }
    // Identical EDIDs cannot uniquely identify two physical monitors; retain connector distinction.
    let ids: Vec<_> = ms.iter().map(|m| m.identity.clone()).collect();
    for m in &mut ms {
        if ids.iter().filter(|id| **id == m.identity).count() > 1 {
            m.identity = format!("{}@{}", m.identity, m.name)
        }
    }
    ms.sort_by(|a, b| a.identity.cmp(&b.identity));
    Ok(ms)
}
fn detect() -> Result<Vec<Monitor>, String> {
    let out = Command::new("timeout")
        .args(["5", "kscreen-doctor", "-j"])
        .output()
        .map_err(|e| e.to_string())?;
    if !out.status.success() {
        return Err(String::from_utf8_lossy(&out.stderr).trim().to_owned());
    }
    let v: Value = serde_json::from_slice(&out.stdout).map_err(|e| e.to_string())?;
    let mut identities = BTreeMap::new();
    if let Ok(entries) = fs::read_dir("/sys/class/drm") {
        for entry in entries.flatten() {
            let n = entry.file_name().to_string_lossy().into_owned();
            if let Some((_, connector)) = n.split_once('-') {
                if let Ok(bytes) = fs::read(entry.path().join("edid")) {
                    if bytes.len() >= 128 {
                        let hex: String = bytes.iter().map(|b| format!("{b:02x}")).collect();
                        identities.insert(connector.to_owned(), format!("edid:{hex}"));
                    }
                }
            }
        }
    }
    parse_monitors(&v, &identities)
}
fn save(path: &PathBuf, c: &Config) -> Result<(), String> {
    let parent = path.parent().ok_or("Invalid config path")?;
    fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    let temp = path.with_extension("json.tmp");
    fs::write(&temp, serde_json::to_vec_pretty(c).unwrap()).map_err(|e| e.to_string())?;
    fs::rename(temp, path).map_err(|e| e.to_string())
}
impl State {
    fn update(&mut self, ms: Vec<Monitor>) -> Result<(), String> {
        if ms.is_empty() {
            return Err("No active monitors; retaining saved profiles".into());
        }
        let base_key = profile_key(&ms);
        let scoped = ms.len() == 1 && !self.desktop_id.is_empty();
        let key = if scoped {
            json!({"monitors":base_key,"desktop":self.desktop_id}).to_string()
        } else {
            base_key.clone()
        };
        let mut c = self.config.clone();
        let inherited = c.profiles.get(&base_key).cloned();
        c.profiles.entry(key.clone()).or_insert_with(|| {
            if scoped {
                if let Some(mut p) = inherited {
                    p.applications.clear();
                    return p;
                }
            }
            Profile {
                name: classify(&ms).into(),
                applications: BTreeMap::new(),
                custom: BTreeMap::new(),
                layouts: ms
                    .iter()
                    .map(|m| (m.identity.clone(), "halves".into()))
                    .collect(),
            }
        });
        if !self.config.profiles.contains_key(&key) {
            save(&self.path, &c)?
        }
        self.config = c;
        self.monitors = ms;
        self.key = key;
        self.error.clear();
        Ok(())
    }
    fn resolved(&self, identity: &str) -> Vec<[f64; 4]> {
        let Some(p) = self.config.profiles.get(&self.key) else {
            return vec![];
        };
        match p.layouts.get(identity).map(String::as_str) {
            Some("custom") => p
                .custom
                .get(identity)
                .filter(|z| validate_zones(z).is_ok())
                .cloned()
                .unwrap_or_else(|| zones("halves").unwrap()),
            Some(l) => zones(l).unwrap_or_default(),
            _ => vec![],
        }
    }
    fn status(&self) -> String {
        let resolved: BTreeMap<_, _> = self
            .monitors
            .iter()
            .map(|m| (m.name.clone(), self.resolved(&m.identity)))
            .collect();
        let warnings: Vec<_>=self.monitors.iter().filter(|m| {
            self.config.profiles.get(&self.key).is_some_and(|p|p.layouts.get(&m.identity).is_some_and(|l|l=="custom") && p.custom.get(&m.identity).is_none_or(|z|validate_zones(z).is_err()))
        }).map(|m|format!("{}: saved custom layout is invalid. Using two columns until you edit it; original zones are retained.",m.name)).collect();
        json!({"desktop_scoped":self.monitors.len()==1 && !self.desktop_id.is_empty(),"desktop_id":self.desktop_id,"desktop_name":self.desktop_name,"free_move":self.free_move,"modifier_at":self.modifier_at,"modifier_ready":self.modifier_ready,"gap":self.config.gap,"layout_warning":warnings.join("\n"),"placement_helper":self.config.placement_helper,"identify":self.identify.as_ref().filter(|(_,until)|Instant::now()<*until).map(|(name,_)|name),"automatic":self.config.automatic,"drag_overlay":self.config.drag_overlay,"profile_key":self.key,"profile":self.config.profiles.get(&self.key),"zones":resolved,"monitors":self.monitors,"error":self.error,"profiles":self.config.profiles.values().map(|p|&p.name).collect::<Vec<_>>()}).to_string()
    }
}
struct Service(Arc<Mutex<State>>);
#[zbus::interface(name = "org.kde.KDEScreenConf")]
impl Service {
    fn status(&self) -> String {
        self.0.lock().unwrap().status()
    }
    fn desktop_status(&self, desktop_id: &str, desktop_name: &str) -> zbus::fdo::Result<String> {
        if desktop_id.is_empty() || desktop_id.len() > 256 || desktop_name.len() > 1024 {
            return Err(zbus::fdo::Error::InvalidArgs(
                "Invalid virtual desktop".into(),
            ));
        }
        let mut s = self.0.lock().unwrap();
        if s.desktop_id != desktop_id || s.desktop_name != desktop_name {
            let old = (s.desktop_id.clone(), s.desktop_name.clone());
            s.desktop_id = desktop_id.into();
            s.desktop_name = desktop_name.into();
            if !s.monitors.is_empty() {
                let monitors = s.monitors.clone();
                if let Err(e) = s.update(monitors) {
                    s.desktop_id = old.0;
                    s.desktop_name = old.1;
                    return Err(zbus::fdo::Error::Failed(e));
                }
            }
        }
        Ok(s.status())
    }
    fn layout(&self, screen: &str) -> String {
        let s = self.0.lock().unwrap();
        if !s.config.automatic {
            return "[]".into();
        };
        let value = s
            .monitors
            .iter()
            .find(|m| m.name == screen)
            .map(|m| s.resolved(&m.identity))
            .unwrap_or_default();
        serde_json::to_string(&value).unwrap()
    }
    fn set_layout(&self, screen: &str, layout: &str) -> zbus::fdo::Result<()> {
        self.set_scoped_layout(screen, layout, "")
    }
    fn set_scoped_layout(
        &self,
        screen: &str,
        layout: &str,
        expected_profile: &str,
    ) -> zbus::fdo::Result<()> {
        if layout != "custom" && zones(layout).is_none() {
            return Err(zbus::fdo::Error::InvalidArgs("Unknown layout".into()));
        }
        let mut s = self.0.lock().unwrap();
        if !expected_profile.is_empty() && s.key != expected_profile {
            return Err(zbus::fdo::Error::Failed(
                "Desktop or monitor profile changed. Try again.".into(),
            ));
        }
        let id = s
            .monitors
            .iter()
            .find(|m| m.name == screen)
            .map(|m| m.identity.clone())
            .ok_or_else(|| zbus::fdo::Error::InvalidArgs("Monitor disconnected".into()))?;
        let mut c = s.config.clone();
        if layout == "custom"
            && !c
                .profiles
                .get(&s.key)
                .is_some_and(|p| p.custom.contains_key(&id))
        {
            return Err(zbus::fdo::Error::InvalidArgs(
                "Create a custom layout first".into(),
            ));
        }
        if layout == "custom" {
            validate_zones(&c.profiles[&s.key].custom[&id])
                .map_err(zbus::fdo::Error::InvalidArgs)?;
        }
        c.profiles
            .get_mut(&s.key)
            .ok_or_else(|| zbus::fdo::Error::Failed("No active profile".into()))?
            .layouts
            .insert(id, layout.into());
        save(&s.path, &c).map_err(zbus::fdo::Error::Failed)?;
        s.config = c;
        Ok(())
    }
    fn set_custom(
        &self,
        screen: &str,
        expected_profile: &str,
        payload: &str,
    ) -> zbus::fdo::Result<()> {
        let value: Vec<[f64; 4]> = serde_json::from_str(payload)
            .map_err(|e| zbus::fdo::Error::InvalidArgs(e.to_string()))?;
        validate_zones(&value).map_err(zbus::fdo::Error::InvalidArgs)?;
        let mut s = self.0.lock().unwrap();
        if s.key != expected_profile {
            return Err(zbus::fdo::Error::Failed(
                "Monitor configuration changed. Reopen the editor.".into(),
            ));
        }
        let id = s
            .monitors
            .iter()
            .find(|m| m.name == screen)
            .map(|m| m.identity.clone())
            .ok_or_else(|| zbus::fdo::Error::InvalidArgs("Monitor disconnected".into()))?;
        let mut c = s.config.clone();
        let p = c
            .profiles
            .get_mut(&s.key)
            .ok_or_else(|| zbus::fdo::Error::Failed("No profile".into()))?;
        p.custom.insert(id.clone(), value);
        p.layouts.insert(id, "custom".into());
        save(&s.path, &c).map_err(zbus::fdo::Error::Failed)?;
        s.config = c;
        Ok(())
    }
    fn set_gap(&self, gap: u32) -> zbus::fdo::Result<()> {
        if gap > 100 {
            return Err(zbus::fdo::Error::InvalidArgs(
                "Gap must be 0–100 pixels".into(),
            ));
        }
        let mut s = self.0.lock().unwrap();
        let mut c = s.config.clone();
        c.gap = gap;
        save(&s.path, &c).map_err(zbus::fdo::Error::Failed)?;
        s.config = c;
        Ok(())
    }
    fn remember(
        &self,
        expected_profile: &str,
        screen: &str,
        application: &str,
        zone: &str,
    ) -> zbus::fdo::Result<()> {
        let mut s = self.0.lock().unwrap();
        if expected_profile != s.key || !s.config.automatic || !s.error.is_empty() {
            return Err(zbus::fdo::Error::Failed(
                "Profile changed or placement paused".into(),
            ));
        }
        if application.trim().is_empty() || application.len() > 512 {
            return Err(zbus::fdo::Error::InvalidArgs(
                "Invalid application identity".into(),
            ));
        }
        let id = s
            .monitors
            .iter()
            .find(|m| m.name == screen)
            .map(|m| m.identity.clone())
            .ok_or_else(|| zbus::fdo::Error::InvalidArgs("Monitor disconnected".into()))?;
        let zone: usize = zone
            .parse()
            .map_err(|_| zbus::fdo::Error::InvalidArgs("Invalid zone".into()))?;
        if zone >= s.resolved(&id).len() {
            return Err(zbus::fdo::Error::InvalidArgs("Invalid zone".into()));
        }
        let mut c = s.config.clone();
        c.profiles
            .get_mut(expected_profile)
            .unwrap()
            .applications
            .insert(application.into(), Assignment { monitor: id, zone });
        save(&s.path, &c).map_err(zbus::fdo::Error::Failed)?;
        s.config = c;
        Ok(())
    }
    fn set_drag_overlay(&self, enabled: bool) -> zbus::fdo::Result<()> {
        let mut s = self.0.lock().unwrap();
        let mut c = s.config.clone();
        c.drag_overlay = enabled;
        save(&s.path, &c).map_err(zbus::fdo::Error::Failed)?;
        s.config = c;
        Ok(())
    }
    fn set_placement_helper(&self, enabled: bool) -> zbus::fdo::Result<()> {
        let mut s = self.0.lock().unwrap();
        let mut c = s.config.clone();
        c.placement_helper = enabled;
        save(&s.path, &c).map_err(zbus::fdo::Error::Failed)?;
        s.config = c;
        Ok(())
    }
    fn identify(&self, screen: &str) -> zbus::fdo::Result<()> {
        let mut s = self.0.lock().unwrap();
        if !s.monitors.iter().any(|m| m.name == screen) {
            return Err(zbus::fdo::Error::InvalidArgs("Monitor disconnected".into()));
        }
        s.identify = Some((screen.into(), Instant::now() + Duration::from_secs(5)));
        Ok(())
    }
    fn set_automatic(&self, enabled: bool) -> zbus::fdo::Result<()> {
        let mut s = self.0.lock().unwrap();
        let mut c = s.config.clone();
        c.automatic = enabled;
        save(&s.path, &c).map_err(zbus::fdo::Error::Failed)?;
        s.config = c;
        Ok(())
    }
}
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();
    let cmd = args.get(1).map(String::as_str).unwrap_or("status");
    if cmd == "detect" {
        println!("{}", serde_json::to_string_pretty(&detect()?)?);
        return Ok(());
    }
    if cmd != "daemon" {
        let conn = zbus::blocking::Connection::session()?;
        let p = zbus::blocking::Proxy::new(&conn, BUS, PATH, BUS)?;
        match cmd {
            "gap" => {
                let gap: u32 = args.get(2).ok_or("Missing gap")?.parse()?;
                p.call::<_, _, ()>("SetGap", &(gap,))?;
                println!("{}", p.call::<_, _, String>("Status", &())?);
            }
            "status" => println!("{}", p.call::<_, _, String>("Status", &())?),
            "set" => {
                let screen = args.get(2).ok_or("Missing screen")?;
                let layout = args.get(3).ok_or("Missing layout")?;
                if let Some(profile) = args.get(4) {
                    p.call::<_, _, ()>("SetScopedLayout", &(screen, layout, profile))?;
                } else {
                    p.call::<_, _, ()>("SetLayout", &(screen, layout))?;
                }
                println!("{}", p.call::<_, _, String>("Status", &())?);
            }
            "custom" => {
                let screen = args.get(2).ok_or("Missing screen")?;
                let profile = args.get(3).ok_or("Missing profile")?;
                let payload = args.get(4).ok_or("Missing zones JSON")?;
                p.call::<_, _, ()>("SetCustom", &(screen, profile, payload))?;
                println!("{}", p.call::<_, _, String>("Status", &())?);
            }
            "overlay-on" | "overlay-off" => {
                p.call::<_, _, ()>("SetDragOverlay", &(cmd == "overlay-on"))?;
                println!("{}", p.call::<_, _, String>("Status", &())?);
            }
            "helper-on" | "helper-off" => {
                p.call::<_, _, ()>("SetPlacementHelper", &(cmd == "helper-on"))?;
                println!("{}", p.call::<_, _, String>("Status", &())?);
            }
            "identify" => {
                let screen = args.get(2).ok_or("Missing screen")?;
                p.call::<_, _, ()>("Identify", &(screen,))?;
                println!("{}", p.call::<_, _, String>("Status", &())?);
            }
            "pause" | "resume" => {
                p.call::<_, _, ()>("SetAutomatic", &(cmd == "resume"))?;
                println!("{}", p.call::<_, _, String>("Status", &())?);
            }
            _ => {
                return Err(
                    "Usage: kdescreenconf [daemon|status|detect|identify SCREEN|set SCREEN LAYOUT|custom SCREEN PROFILE JSON|overlay-on|overlay-off|pause|resume]".into(),
                );
            }
        }
        return Ok(());
    }
    let base = std::env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(std::env::var_os("HOME").unwrap()).join(".config"));
    let path = base.join("kdescreenconf/profiles.json");
    let config = match fs::read(&path) {
        Ok(b) => serde_json::from_slice::<Config>(&b)?,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Config::default(),
        Err(e) => return Err(e.into()),
    };
    if config.version != 1 {
        return Err("Unsupported configuration version".into());
    }
    let state = Arc::new(Mutex::new(State {
        config,
        monitors: vec![],
        key: String::new(),
        error: "Detecting monitors…".into(),
        path,
        identify: None,
        desktop_id: String::new(),
        desktop_name: String::new(),
        free_move: false,
        modifier_at: 0,
        modifier_ready: false,
    }));
    let modifier_state = state.clone();
    thread::spawn(move || {
        loop {
            if let Err(e) = modifiers::listen(modifier_state.clone()) {
                eprintln!("Modifier listener unavailable: {e}. Use Ctrl+Meta+D to skip snapping.");
                let mut s = modifier_state.lock().unwrap();
                s.modifier_ready = false;
                s.free_move = false;
            }
            thread::sleep(Duration::from_secs(5));
        }
    });
    let _conn = zbus::blocking::connection::Builder::session()?
        .name(BUS)?
        .serve_at(PATH, Service(state.clone()))?
        .build()?;
    let mut candidate = vec![];
    let mut stable = 0;
    loop {
        match detect() {
            Ok(ms) => {
                if ms == candidate {
                    stable += 1
                } else {
                    candidate = ms.clone();
                    stable = 0
                }
                if stable >= 2 {
                    let mut s = state.lock().unwrap();
                    if let Err(e) = s.update(ms) {
                        s.error = e
                    }
                }
            }
            Err(e) => {
                state.lock().unwrap().error = e;
                stable = 0;
            }
        }
        thread::sleep(Duration::from_secs(2));
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    fn m(name: &str, internal: bool, w: u64) -> Monitor {
        Monitor {
            name: name.into(),
            identity: name.into(),
            width: w,
            height: 1080,
            internal,
        }
    }
    #[test]
    fn custom_validation() {
        assert!(validate_zones(&[]).is_err());
        assert!(validate_zones(&vec![[0., 0., 1., 1.]; 10]).is_err());
        for z in [
            [-0.1, 0., 0.5, 1.],
            [0.9, 0., 0.5, 1.],
            [0., 0., 0.01, 1.],
            [0., 0., f64::NAN, 1.],
        ] {
            assert!(validate_zones(&[z]).is_err());
        }
        assert!(validate_zones(&[[0., 0., 1., 1.], [0.25, 0.25, 0.5, 0.5]]).is_err());
        let old: Config =
            serde_json::from_str(r#"{"version":1,"automatic":true,"profiles":{}}"#).unwrap();
        assert!(old.drag_overlay);
        assert!(old.placement_helper);
        assert!(validate_zones(&[[0., 0., 0.5, 1.], [0.5, 0., 0.5, 1.]]).is_ok());
        assert!(validate_zones(&[[0., 0., 0.5, 0.5], [0.5, 0.5, 0.5, 0.5]]).is_ok());
        assert!(validate_zones(&[[0., 0., 0.6, 1.], [0.5, 0., 0.5, 1.]]).is_err());
    }
    #[test]
    fn custom_save_rejects_stale_profile_and_survives_restart() {
        let path = std::env::temp_dir().join(format!(
            "kdescreenconf-custom-{}/profiles.json",
            std::process::id()
        ));
        let mut state = State {
            config: Config::default(),
            monitors: vec![],
            key: String::new(),
            error: String::new(),
            path: path.clone(),
            identify: None,
            desktop_id: String::new(),
            desktop_name: String::new(),
            free_move: false,
            modifier_at: 0,
            modifier_ready: false,
        };
        state.update(vec![m("laptop", true, 1920)]).unwrap();
        let key = state.key.clone();
        let shared = Arc::new(Mutex::new(state));
        let service = Service(shared.clone());
        assert!(service.identify("missing").is_err());
        service.identify("laptop").unwrap();
        assert_eq!(
            serde_json::from_str::<Value>(&service.status()).unwrap()["identify"],
            "laptop"
        );
        shared.lock().unwrap().identify =
            Some(("laptop".into(), Instant::now() - Duration::from_secs(1)));
        assert!(serde_json::from_str::<Value>(&service.status()).unwrap()["identify"].is_null());
        assert!(
            service
                .set_custom("laptop", "stale", "[[0,0,1,1]]")
                .is_err()
        );
        assert!(service.set_custom("missing", &key, "[[0,0,1,1]]").is_err());
        assert!(service.set_custom("laptop", &key, "[[0,0,2,1]]").is_err());
        service
            .set_custom("laptop", &key, "[[0,0,0.6,1],[0.6,0,0.4,1]]")
            .unwrap();
        service.set_layout("laptop", "halves").unwrap();
        service.set_layout("laptop", "custom").unwrap();
        let saved: Config = serde_json::from_slice(&fs::read(&path).unwrap()).unwrap();
        assert_eq!(saved.profiles[&key].custom["laptop"][0][2], 0.6);
        assert_eq!(
            serde_json::from_str::<Vec<[f64; 4]>>(&service.layout("laptop"))
                .unwrap()
                .len(),
            2
        );
        {
            let mut s = shared.lock().unwrap();
            s.config.profiles.get_mut(&key).unwrap().custom.insert(
                "laptop".into(),
                vec![[0., 0., 1., 1.], [0.25, 0.25, 0.5, 0.5]],
            );
        }
        assert_eq!(
            serde_json::from_str::<Vec<[f64; 4]>>(&service.layout("laptop")).unwrap(),
            zones("halves").unwrap()
        );
        assert!(
            !serde_json::from_str::<Value>(&service.status()).unwrap()["layout_warning"]
                .as_str()
                .unwrap()
                .is_empty()
        );
        assert!(service.set_layout("laptop", "custom").is_err());
        service.set_automatic(false).unwrap();
        assert_eq!(service.layout("laptop"), "[]");
        fs::remove_dir_all(path.parent().unwrap()).unwrap();
    }
    #[test]
    fn assignments_and_gap_persist_per_profile() {
        let path = std::env::temp_dir().join(format!(
            "kdescreenconf-assignments-{}/profiles.json",
            std::process::id()
        ));
        let mut state = State {
            config: Config::default(),
            monitors: vec![],
            key: String::new(),
            error: String::new(),
            path: path.clone(),
            identify: None,
            desktop_id: String::new(),
            desktop_name: String::new(),
            free_move: false,
            modifier_at: 0,
            modifier_ready: false,
        };
        state.update(vec![m("laptop", true, 1920)]).unwrap();
        let mobile = state.key.clone();
        let shared = Arc::new(Mutex::new(state));
        let service = Service(shared.clone());
        assert_eq!(shared.lock().unwrap().config.gap, 2);
        assert!(service.set_gap(101).is_err());
        service.set_gap(3).unwrap();
        assert!(service.remember("stale", "laptop", "browser", "0").is_err());
        assert!(service.remember(&mobile, "laptop", "browser", "9").is_err());
        service.remember(&mobile, "laptop", "browser", "1").unwrap();
        shared
            .lock()
            .unwrap()
            .update(vec![m("laptop", true, 1920), m("external", false, 3840)])
            .unwrap();
        let desk = shared.lock().unwrap().key.clone();
        service.remember(&desk, "external", "browser", "0").unwrap();
        let saved: Config = serde_json::from_slice(&fs::read(&path).unwrap()).unwrap();
        assert_eq!(saved.gap, 3);
        assert_eq!(saved.profiles[&mobile].applications["browser"].zone, 1);
        assert_eq!(
            saved.profiles[&desk].applications["browser"].monitor,
            "external"
        );
        service.set_automatic(false).unwrap();
        assert!(service.remember(&desk, "external", "browser", "1").is_err());
        fs::remove_dir_all(path.parent().unwrap()).unwrap();
    }
    #[test]
    fn single_monitor_desktops_are_independent_and_persistent() {
        let path = std::env::temp_dir().join(format!(
            "kdescreenconf-desktops-{}/profiles.json",
            std::process::id()
        ));
        let mut state = State {
            config: Config::default(),
            monitors: vec![],
            key: String::new(),
            error: String::new(),
            path: path.clone(),
            identify: None,
            desktop_id: String::new(),
            desktop_name: String::new(),
            free_move: false,
            modifier_at: 0,
            modifier_ready: false,
        };
        let laptop = m("laptop", true, 1920);
        state.update(vec![laptop.clone()]).unwrap();
        let base = state.key.clone();
        let shared = Arc::new(Mutex::new(state));
        let service = Service(shared.clone());
        service.set_layout("laptop", "quarters").unwrap();
        service.desktop_status("uuid-a", "Work").unwrap();
        let a = shared.lock().unwrap().key.clone();
        assert_ne!(a, base);
        assert_eq!(shared.lock().unwrap().resolved("laptop").len(), 4);
        service.set_layout("laptop", "left-stack").unwrap();
        service.remember(&a, "laptop", "app", "2").unwrap();
        service.desktop_status("uuid-b", "Personal").unwrap();
        let b = shared.lock().unwrap().key.clone();
        assert_ne!(a, b);
        assert_eq!(shared.lock().unwrap().resolved("laptop").len(), 4);
        assert!(service.set_scoped_layout("laptop", "full", &a).is_err());
        assert!(service.set_custom("laptop", &a, "[[0,0,1,1]]").is_err());
        assert!(service.remember(&a, "laptop", "app", "0").is_err());
        service.set_layout("laptop", "halves").unwrap();
        service.remember(&b, "laptop", "app", "0").unwrap();
        service.desktop_status("uuid-a", "Renamed Work").unwrap();
        assert_eq!(shared.lock().unwrap().key, a);
        assert_eq!(shared.lock().unwrap().resolved("laptop").len(), 3);
        let saved: Config = serde_json::from_slice(&fs::read(&path).unwrap()).unwrap();
        assert_eq!(saved.profiles[&a].applications["app"].zone, 2);
        assert_eq!(saved.profiles[&b].applications["app"].zone, 0);
        assert_eq!(saved.profiles[&base].layouts["laptop"], "quarters");
        shared.lock().unwrap().config = saved;
        shared
            .lock()
            .unwrap()
            .update(vec![laptop.clone(), m("external", false, 3840)])
            .unwrap();
        let multi = shared.lock().unwrap().key.clone();
        service.desktop_status("uuid-b", "Personal").unwrap();
        assert_eq!(shared.lock().unwrap().key, multi);
        shared.lock().unwrap().update(vec![laptop]).unwrap();
        assert_eq!(shared.lock().unwrap().key, b);
        fs::remove_dir_all(path.parent().unwrap()).unwrap();
    }
    #[test]
    fn four_profiles() {
        let laptop = m("laptop", true, 1920);
        assert_eq!(classify(&[laptop.clone()]), "Mobile");
        assert_eq!(
            classify(&[laptop.clone(), m("wide", false, 3440)]),
            "Wide desk"
        );
        assert_eq!(
            classify(&[laptop, m("a", false, 1920), m("b", false, 1920)]),
            "Dual desk"
        );
        assert_eq!(
            classify(&[
                m("a", false, 3840),
                m("b", false, 3840),
                m("c", false, 3840),
                m("d", false, 1920),
                m("e", false, 1920)
            ]),
            "Workstation"
        );
    }
    #[test]
    fn order_independent() {
        let a = m("a", false, 3840);
        let b = m("b", true, 1920);
        assert_eq!(
            profile_key(&[a.clone(), b.clone()]),
            profile_key(&[b.clone(), a])
        );
        assert_ne!(
            profile_key(&[b.clone()]),
            profile_key(&[b, m("c", false, 1920)])
        );
    }
    #[test]
    fn valid_zones() {
        for l in [
            "full",
            "halves",
            "thirds",
            "priority",
            "quarters",
            "left-stack",
        ] {
            let z = zones(l).unwrap();
            assert!((z.iter().map(|r| r[2] * r[3]).sum::<f64>() - 1.).abs() < 1e-8);
            for r in z {
                assert!(r[0] + r[2] <= 1.000001 && r[1] + r[3] <= 1.000001)
            }
        }
        assert!(zones("invalid").is_none())
    }
    #[test]
    fn disabled_ignored_and_duplicates_disambiguated() {
        let v = json!({"outputs":[{"name":"a","enabled":true,"connected":true,"size":{"width":1920,"height":1080}},{"name":"b","enabled":true,"connected":true},{"name":"eDP-1","enabled":false,"connected":true}]});
        let ids = BTreeMap::from([("a".into(), "same".into()), ("b".into(), "same".into())]);
        let ms = parse_monitors(&v, &ids).unwrap();
        assert_eq!(ms.len(), 2);
        assert_ne!(ms[0].identity, ms[1].identity);
    }
    #[test]
    fn persistence_and_profile_isolation() {
        let path = std::env::temp_dir().join(format!(
            "kdescreenconf-test-{}/profiles.json",
            std::process::id()
        ));
        let mut s = State {
            config: Config::default(),
            monitors: vec![],
            key: String::new(),
            error: String::new(),
            path: path.clone(),
            identify: None,
            desktop_id: String::new(),
            desktop_name: String::new(),
            free_move: false,
            modifier_at: 0,
            modifier_ready: false,
        };
        let a = m("laptop", true, 1920);
        s.update(vec![a.clone()]).unwrap();
        s.config
            .profiles
            .get_mut(&s.key)
            .unwrap()
            .layouts
            .insert(a.identity.clone(), "quarters".into());
        s.update(vec![a.clone(), m("ext", false, 3840)]).unwrap();
        assert_eq!(s.config.profiles[&s.key].layouts[&a.identity], "halves");
        s.update(vec![a.clone()]).unwrap();
        assert_eq!(s.config.profiles[&s.key].layouts[&a.identity], "quarters");
        let c: Config = serde_json::from_slice(&fs::read(&path).unwrap()).unwrap();
        assert_eq!(c.profiles.len(), 2);
        fs::remove_dir_all(path.parent().unwrap()).unwrap();
    }
}
