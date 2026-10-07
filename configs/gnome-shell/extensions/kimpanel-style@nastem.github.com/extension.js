// The candidate-window styling is all in stylesheet.css, which GNOME Shell
// loads for every enabled extension. The code only hides kimpanel's top-bar
// indicator: the Fcitx tray icon already shows the input method state.
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

// Main.panel.addToStatusArea() role used by kimpanel@kde.org
const INDICATOR_ROLE = 'kimpanel';

export default class KimpanelStyleExtension extends Extension {
    enable() {
        // kimpanel creates its indicator in its own enable(), which may run
        // before or after ours, and recreates it when re-enabled.
        this._stateChangedId = Main.extensionManager.connect(
            'extension-state-changed', () => this._setIndicatorVisible(false));
        this._setIndicatorVisible(false);
    }

    disable() {
        Main.extensionManager.disconnect(this._stateChangedId);
        this._stateChangedId = null;
        this._setIndicatorVisible(true);
    }

    _setIndicatorVisible(visible) {
        // Toggle the panel container: kimpanel calls show() on the indicator
        // button itself whenever input method properties change.
        Main.panel.statusArea[INDICATOR_ROLE]?.container.set_visible(visible);
    }
}
