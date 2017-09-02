/*-
 * Copyright (c) 2015 Erasmo Marín <erasmo.marin@gmail.com>
 * Copyright (c) 2017-2017 Artem Anufrij <artem.anufrij@live.de>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * The Noise authors hereby grant permission for non-GPL compatible
 * GStreamer plugins to be used and distributed together with GStreamer
 * and Noise. This permission is above and beyond the permissions granted
 * by the GPL license by which Noise is covered. If you modify this code
 * you may extend this exception to your version of the code, but you are not
 * obligated to do so. If you do not wish to do so, delete this exception
 * statement from your version.
 *
 * Authored by: Artem Anufrij <artem.anufrij@live.de>
 */

namespace Webpin {
    public class WebWindow : Gtk.Window {

        private bool is_full_screen = false;

        private string style_str =   """@define-color titlebar_color @titlebar_color;""";

        //widgets
        private WebApp web_app;

        Gtk.Spinner spinner;

        public DesktopFile desktop_file { get; private set; }

        public WebWindow (DesktopFile desktop_file) {
            this.desktop_file = desktop_file;
            this.events |= Gdk.EventMask.STRUCTURE_MASK;

            set_wmclass(desktop_file.url, desktop_file.url);
            web_app = new WebApp(desktop_file.name, desktop_file.url);

            var headerbar = new Gtk.HeaderBar ();
            headerbar.title = desktop_file.name;
            headerbar.show_close_button = true;

            spinner = new Gtk.Spinner ();
            spinner.set_size_request (16, 16);
            headerbar.pack_end (spinner);

            //style
            if (web_app.ui_color != "none") {
                try {
                    debug ("set color");
                    var style_cp = style_str.replace ("@titlebar_color", web_app.ui_color);
                    var style_provider = new Gtk.CssProvider ();
                    style_provider.load_from_data (style_cp, -1);
                    headerbar.get_style_context ().add_provider (style_provider, -1);
                    Gtk.Settings.get_default ().set ("gtk-application-prefer-dark-theme", should_use_dark_theme (web_app.ui_color));
                } catch (GLib.Error err) {
                    warning("Loading style failed");
                }
            }

            web_app.theme_color_changed.connect( (color)=> {
                try {
                    debug ("set color");
                    var style_cp = style_str.replace ("@titlebar_color", color);
                    var style_provider = new Gtk.CssProvider ();
                    style_provider.load_from_data (style_cp, -1);
                    headerbar.get_style_context ().add_provider (style_provider, -1);
                    Gtk.Settings.get_default ().set ("gtk-application-prefer-dark-theme", should_use_dark_theme (color));
                } catch (GLib.Error err) {
                    warning("Loading style failed");
                }
            });

            this.set_titlebar (headerbar);

            var width = desktop_file.info.get_string ("WebpinWindowWidth");
            var height = desktop_file.info.get_string ("WebpinWindowHeight");
            var state = desktop_file.info.get_string ("WebpinWindowMaximized");
            var zoom = desktop_file.info.get_string ("WebpinWindowZoom");

            if (width != null && height != null) {
                set_default_size (int.parse(width), int.parse(height));
            } else {
                set_default_size (1000, 600);
            }

            if (state != null && state == "max") {
                this.maximize ();
            }

            if (zoom != null) {
                web_app.app_view.zoom_level = double.parse (zoom);
            }

            this.delete_event.connect (() => {
                update_window_state(this.get_allocated_width (), this.get_allocated_height (), this.is_maximized);
                if (desktop_file.hide_on_close) {
                    this.hide ();
                }
                return desktop_file.hide_on_close;
            });

            web_app.external_request.connect ((action) => {
                debug ("Web app external request: %s", action.get_request ().uri);
                try {
                    Process.spawn_command_line_async ("xdg-open " + action.get_request ().uri);
                } catch (Error e) {
                    warning (e.message);
                }
            });

            web_app.request_begin.connect (() => {
                spinner.active = true;
            });

            web_app.request_finished.connect (() => {
                spinner.active = false;
            });

            add(web_app);
            show_all();
        }

        public new void fullscreen () {
            is_full_screen = true;
            base.fullscreen();
        }

        public new void unfullscreen () {
            is_full_screen = false;
            base.unfullscreen();
        }

        public void toggle_fullscreen() {
            if(is_full_screen)
                unfullscreen();
            else
                fullscreen();
            is_full_screen = !is_full_screen;
        }

        public void update_window_state (int width, int height, bool is_maximized) {
            var file = web_app.get_desktop_file();

            if (is_maximized) {
                file.edit_propertie ("WebpinWindowMaximized", "max");
            } else {
                file.edit_propertie ("WebpinWindowWidth", width.to_string());
                file.edit_propertie ("WebpinWindowHeight", height.to_string());
                file.edit_propertie ("WebpinWindowMaximized", "norm");
            }
        }

        public override bool key_press_event (Gdk.EventKey event) {
            bool handled = true;
            switch (event.keyval) {
            case Gdk.Key.Escape:
                unfullscreen();
                break;
            case Gdk.Key.F11:
                toggle_fullscreen();
                break;
            case Gdk.Key.KP_Add:
            case Gdk.Key.plus:
                if (Gdk.ModifierType.CONTROL_MASK in event.state) {
                    web_app.app_view.zoom_level += 0.1;
                    web_app.get_desktop_file().edit_propertie ("WebpinWindowZoom", web_app.app_view.zoom_level.to_string ());
                } else {
                    handled = false;
                }
                break;
            case Gdk.Key.KP_Subtract:
            case Gdk.Key.minus:
                if (Gdk.ModifierType.CONTROL_MASK in event.state) {
                    web_app.app_view.zoom_level -= 0.1;
                    web_app.get_desktop_file().edit_propertie ("WebpinWindowZoom", web_app.app_view.zoom_level.to_string ());
                } else {
                    handled = false;
                }
                break;
            case Gdk.Key.KP_0:
            case Gdk.Key.@0:
                if (Gdk.ModifierType.CONTROL_MASK in event.state) {
                    web_app.app_view.zoom_level = 1;
                    web_app.get_desktop_file().edit_propertie ("WebpinWindowZoom", web_app.app_view.zoom_level.to_string ());
                } else {
                    handled = false;
                }
                break;
            case Gdk.Key.F5:
                if (Gdk.ModifierType.CONTROL_MASK in event.state) {
                    web_app.app_view.reload ();
                } else {
                    web_app.app_view.reload_bypass_cache ();
                }
                break;
            case Gdk.Key.Left:
                if (Gdk.ModifierType.MOD1_MASK in event.state) {
                    web_app.app_view.go_back ();
                } else {
                    handled = false;
                }
                break;
            case Gdk.Key.Right:
                if (Gdk.ModifierType.MOD1_MASK in event.state) {
                    web_app.app_view.go_forward ();
                } else {
                    handled = false;
                }
                break;
            default:
                handled = false;
                break;
            }

            if (handled)
                return true;

            return (base.key_press_event != null) ? base.key_press_event (event) : true;
        }

        private bool should_use_dark_theme (string theme_color) {
            Gdk.RGBA color = {};
            color.parse (theme_color);

            double prom = (color.red + color.blue + color.green)/3;

            if (prom < 0.5)
                return true;
            return false;
        }
    }
}
