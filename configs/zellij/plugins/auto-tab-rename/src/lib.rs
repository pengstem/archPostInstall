use std::collections::BTreeMap;

use zellij_tile::prelude::*;

const DEFAULT_MAX_TABS: usize = 30;
const DEFAULT_TICK_SECONDS: f64 = 0.5;

#[derive(Default)]
struct State {
    only_numeric: bool,
    prefix: String,
    max_tabs: usize,
    tick_seconds: f64,
    last_tabs: Option<Vec<TabInfo>>,
    permission_granted: Option<bool>,
}

impl ZellijPlugin for State {
    fn load(&mut self, configuration: BTreeMap<String, String>) {
        self.only_numeric = configuration
            .get("only_numeric")
            .map(|v| v == "true")
            .unwrap_or(true);
        self.prefix = configuration.get("prefix").cloned().unwrap_or_default();
        self.max_tabs = configuration
            .get("max_tabs")
            .and_then(|v| v.parse::<usize>().ok())
            .unwrap_or(DEFAULT_MAX_TABS);
        self.tick_seconds = configuration
            .get("tick_seconds")
            .and_then(|v| v.parse::<f64>().ok())
            .unwrap_or(DEFAULT_TICK_SECONDS);

        request_permission(&[
            PermissionType::ReadApplicationState,
            PermissionType::ChangeApplicationState,
        ]);
        subscribe(&[
            EventType::PermissionRequestResult,
            EventType::TabUpdate,
            EventType::Timer,
        ]);
        // Some sessions don't emit a `TabUpdate` immediately on startup, and some users might
        // have an old plugin cache. A short timer makes sure we still renumber early.
        set_timeout(0.1);
    }

    fn update(&mut self, event: Event) -> bool {
        match event {
            Event::PermissionRequestResult(status) => {
                self.permission_granted = Some(matches!(status, PermissionStatus::Granted));
                // Retry quickly after a permission decision.
                set_timeout(0.1);
            }
            Event::TabUpdate(tabs) => {
                self.last_tabs = Some(tabs);
                if self.permission_granted != Some(false) {
                    if let Some(tabs) = self.last_tabs.as_ref() {
                        renumber_tabs(tabs, &self.prefix, self.only_numeric);
                    }
                }
            }
            Event::Timer(_) => {
                if self.permission_granted != Some(false) {
                    if let Some(tabs) = self.last_tabs.as_ref() {
                        renumber_tabs(tabs, &self.prefix, self.only_numeric);
                    } else if !self.only_numeric {
                        // Without `TabUpdate` we can't preserve custom names, but when
                        // `only_numeric` is disabled we can still enforce numeric naming.
                        renumber_positions(self.max_tabs, &self.prefix);
                    }
                }
                set_timeout(self.tick_seconds);
            }
            _ => {}
        }
        false
    }
}

fn renumber_tabs(tabs: &[TabInfo], prefix: &str, only_numeric: bool) {
    for tab in tabs {
        // `tab.position` is 0-indexed, but Zellij UI / keybinds are 1-indexed.
        let display_position = tab.position.saturating_add(1);
        let desired = format!("{}{}", prefix, display_position);
        if tab.name == desired {
            continue;
        }
        if only_numeric && !is_renumberable(&tab.name) {
            continue;
        }
        if let Ok(position) = u32::try_from(tab.position) {
            rename_tab(position, desired);
        }
    }
}

fn renumber_positions(max_tabs: usize, prefix: &str) {
    for tab_position in 0..max_tabs {
        let display_position = tab_position.saturating_add(1);
        rename_tab(tab_position as u32, format!("{}{}", prefix, display_position));
    }
}

fn is_renumberable(name: &str) -> bool {
    let trimmed = name.trim();
    if trimmed.is_empty() || trimmed.chars().all(|c| c.is_ascii_digit()) {
        return true;
    }
    // Zellij's default tab names are "Tab #<n>" - allow renumbering those too.
    let Some(rest) = trimmed.strip_prefix("Tab #") else {
        return false;
    };
    let rest = rest.trim();
    !rest.is_empty() && rest.chars().all(|c| c.is_ascii_digit())
}

register_plugin!(State);
