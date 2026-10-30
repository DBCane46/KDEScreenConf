// Read only the public KDE modifier-state protocol, never raw keyboard input.
use crate::State;
use std::sync::{Arc, Mutex};
use wayland_client::{Connection, Dispatch, QueueHandle, protocol::wl_registry};
use wayland_protocols_plasma::keystate::client::org_kde_kwin_keystate::{self, OrgKdeKwinKeystate};
struct Listener {
    state: Arc<Mutex<State>>,
    control: bool,
    meta: bool,
}
impl Dispatch<wl_registry::WlRegistry, wayland_client::globals::GlobalListContents> for Listener {
    fn event(
        _: &mut Self,
        _: &wl_registry::WlRegistry,
        _: wl_registry::Event,
        _: &wayland_client::globals::GlobalListContents,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}
impl Dispatch<OrgKdeKwinKeystate, ()> for Listener {
    fn event(
        s: &mut Self,
        _: &OrgKdeKwinKeystate,
        event: org_kde_kwin_keystate::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        if let org_kde_kwin_keystate::Event::StateChanged { key, state } = event {
            match key {
                4 => s.control = state == 3,
                6 => s.meta = state == 3,
                _ => return,
            }
            let mut shared = s.state.lock().unwrap();
            let held = s.control && s.meta;
            if held && !shared.free_move {
                shared.modifier_at = std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_millis() as u64;
            }
            shared.free_move = held;
        }
    }
}
pub fn listen(state: Arc<Mutex<State>>) -> Result<(), Box<dyn std::error::Error>> {
    let conn = Connection::connect_to_env()?;
    let (globals, mut queue) = wayland_client::globals::registry_queue_init::<Listener>(&conn)?;
    let keys: OrgKdeKwinKeystate = globals.bind(&queue.handle(), 5..=5, ())?;
    let mut listener = Listener {
        state: state.clone(),
        control: false,
        meta: false,
    };
    keys.fetchStates();
    queue.roundtrip(&mut listener)?;
    state.lock().unwrap().modifier_ready = true;
    loop {
        queue.blocking_dispatch(&mut listener)?;
    }
}
