use std::collections::BTreeMap;

use zellij_tile::prelude::*;

#[derive(Default)]
struct State {
    only_numeric: bool,
    prefix: String,
}

impl ZellijPlugin for State {
    fn load(&mut self, configuration: BTreeMap<String, String>) {
        self.only_numeric = configuration
            .get("only_numeric")
            .map(|v| v == "true")
            .unwrap_or(true);
        self.prefix = configuration.get("prefix").cloned().unwrap_or_default();

        request_permission(&[
            PermissionType::ReadApplicationState,
            PermissionType::ChangeApplicationState,
        ]);
        subscribe(&[EventType::TabUpdate]);
    }

    fn update(&mut self, event: Event) -> bool {
        if let Event::TabUpdate(tabs) = event {
            renumber_tabs(&tabs, &self.prefix, self.only_numeric);
        }
        false
    }
}

fn renumber_tabs(tabs: &[TabInfo], prefix: &str, only_numeric: bool) {
    for tab in tabs {
        let desired = format!("{}{}", prefix, tab.position);
        if tab.name == desired {
            continue;
        }
        if only_numeric && !is_numeric_or_empty(&tab.name) {
            continue;
        }
        if let Ok(position) = u32::try_from(tab.position) {
            rename_tab(position, desired);
        }
    }
}

fn is_numeric_or_empty(name: &str) -> bool {
    let trimmed = name.trim();
    trimmed.is_empty() || trimmed.chars().all(|c| c.is_ascii_digit())
}

register_plugin!(State);
