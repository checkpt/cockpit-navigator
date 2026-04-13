/* 
	Cockpit Navigator - A File System Browser for Cockpit.
	Copyright (C) 2021 Josh Boudreau      <jboudreau@45drives.com>
	Copyright (C) 2021 Sam Silver         <ssilver@45drives.com>
	Copyright (C) 2021 Dawson Della Valle <ddellavalle@45drives.com>

	This file is part of Cockpit Navigator.
	Cockpit Navigator is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.
	Cockpit Navigator is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.
	You should have received a copy of the GNU General Public License
	along with Cockpit Navigator.  If not, see <https://www.gnu.org/licenses/>.
 */

import { ModalPrompt } from "./components/ModalPrompt.js";
import { NavWindow } from "./components/NavWindow.js";
import { NAVIGATOR_VERSION } from "./version.js";
import { _ } from "./i18n.js";

/**
 * 
 * @param {NavWindow} nav_window 
 */
function load_hidden_file_state(nav_window) {
	const state = localStorage.getItem('show-hidden-files') === 'true';
	const element = document.querySelector('#nav-show-hidden');

	if (state) {
		element.checked = true;
		nav_window.toggle_show_hidden({ target: element });
	}
}

/**
 * 
 * @param {NavWindow} nav_window 
 */
 function load_item_display_state(nav_window) {
	const state = localStorage.getItem('item-display');

	if (state === 'list') {
		nav_window.switch_item_display();
	}
}

function apply_theme(state) {
	var toggle_switch = document.getElementById("toggle-theme");
	var icon = document.getElementById("houston-theme-icon");
	var logo = document.getElementById("logo-45d");
	if (state === "dark") {
		toggle_switch.checked = true;
		document.documentElement.setAttribute("data-theme", "dark");
		icon.classList.remove("fa-sun");
		icon.classList.add("fa-moon");
		logo.src = "branding/logo-dark.svg";
	} else {
		toggle_switch.checked = false;
		document.documentElement.setAttribute("data-theme", "light");
		icon.classList.remove("fa-moon");
		icon.classList.add("fa-sun");
		logo.src = "branding/logo-light.svg";
	}
}

function set_last_theme_state() {
	var state = localStorage.getItem("shell:style") || "light";
	apply_theme(state);
	localStorage.setItem("houston-theme-state", state);
}

/**
 * 
 * @param {Event} e 
 */
function switch_theme(e) {
	var state = e.target.checked ? "dark" : "light";
	apply_theme(state);
	localStorage.setItem("houston-theme-state", state);
	localStorage.setItem("shell:style", state);
}

let nav_window = new NavWindow();

function set_up_buttons() {
	document.getElementById("nav-back-btn").addEventListener("click", nav_window.back.bind(nav_window));
	document.getElementById("nav-forward-btn").addEventListener("click", nav_window.forward.bind(nav_window));
	document.getElementById("nav-up-dir-btn").addEventListener("click", nav_window.up.bind(nav_window));
	document.getElementById("nav-refresh-btn").addEventListener("click", nav_window.refresh.bind(nav_window));
	document.getElementById("nav-mkdir-btn").addEventListener("click", nav_window.mkdir.bind(nav_window));
	document.getElementById("nav-touch-btn").addEventListener("click", nav_window.touch.bind(nav_window));
	document.getElementById("nav-ln-btn").addEventListener("click", nav_window.ln.bind(nav_window, ""));
	document.getElementById("nav-delete-btn").addEventListener("click", nav_window.delete_selected.bind(nav_window));
	document.getElementById("nav-edit-properties-btn").addEventListener("click", nav_window.show_edit_selected.bind(nav_window));
	document.getElementById("nav-cancel-edit-btn").addEventListener("click", nav_window.hide_edit_selected.bind(nav_window));
	document.getElementById("nav-apply-edit-btn").addEventListener("click", nav_window.apply_edit_selected.bind(nav_window));
	var mode_checkboxes = document.getElementsByClassName("mode-checkbox");
	for (let checkbox of mode_checkboxes) {
		checkbox.addEventListener("change", nav_window.update_permissions_preview.bind(nav_window));
	}
	document.getElementById("pwd").addEventListener("input", nav_window.nav_bar_update_choices.bind(nav_window), false);
	document.getElementById("pwd").addEventListener("focus", nav_window.nav_bar_update_choices.bind(nav_window), false);
	document.getElementById("pwd").addEventListener("keydown", nav_window.nav_bar_event_handler.bind(nav_window));
	document.getElementById("toggle-theme").addEventListener("change", switch_theme, false);
	document.getElementById("nav-show-hidden").addEventListener("change", nav_window.toggle_show_hidden.bind(nav_window));
	document.getElementById("nav-item-display-btn").addEventListener("click", nav_window.switch_item_display.bind(nav_window));
	for (let option of ["name", "owner", "group", "size", "modified", "created"]) {
		var elem = document.getElementById("sort-" + option + "-btn");
		elem.addEventListener("click", (event) => {
			nav_window.sort_function.set_func(option);
			nav_window.refresh();
		});
	}
	document.getElementById("search-bar").addEventListener("input", nav_window.search_filter.bind(nav_window));
	document.getElementById("search-bar").addEventListener("keydown", (e) => {
		if (e.keyCode === 13)
			nav_window.search_filter(e);
		e.stopPropagation();
	});
	// fix tab in editor input
	document.getElementById('nav-edit-contents-textarea').addEventListener('keydown', (e) => {
		if (e.key == 'Tab') {
			e.preventDefault();
			var start = e.target.selectionStart;
			var end = e.target.selectionEnd;
			e.target.value = `${e.target.value.substring(0, start)}\t${e.target.value.substring(end)}`;
			e.target.selectionStart = e.target.selectionEnd = start + 1;
		}
	});
	document.getElementById("nav-info-btn").addEventListener("click", () => {
		new ModalPrompt().alert(
			cockpit.format(_("Cockpit Navigator $0"), NAVIGATOR_VERSION),
			`<p>` +
			cockpit.format(_("Created by $0 for Houston UI (Cockpit)."), '<a target="_blank" href=https://www.45drives.com/?utm_source=Houston&utm_medium=UI&utm_campaign=OS-Link>45Drives</a>') + `<br>` +
			`<a target="_blank" href=https://github.com/45Drives/cockpit-navigator/issues>` + _("Issue Tracker") + `</a><br>` +
			`<a target="_blank" href=https://github.com/45Drives/cockpit-navigator/discussions>` + _("Feedback") + `</a><br>` +
			`</p>`
		);
	});
}

function listen_storage_changes() {
	window.addEventListener("storage", (e) => {
		if (e.key === "shell:style" || e.key === "houston-theme-state") {
			apply_theme(e.newValue);
		}
	});
}

function translate_html() {
	// Translate title attributes
	var title_map = {
		"nav-back-btn": _("Back"),
		"nav-forward-btn": _("Forward"),
		"nav-up-dir-btn": _("Up"),
		"nav-refresh-btn": _("Refresh"),
		"pwd": _("Navigation Bar"),
		"nav-mkdir-btn": _("New Directory"),
		"nav-touch-btn": _("New File"),
		"nav-ln-btn": _("New Symbolic Link"),
		"nav-upload-btn": _("Upload File(s)"),
		"nav-cancel-edit-contents-btn": _("Cancel"),
		"nav-continue-edit-contents-btn": _("Save"),
		"nav-delete-btn": _("Delete"),
		"nav-edit-properties-btn": _("Edit Properties"),
		"nav-edit-contents-btn": _("Edit Contents"),
		"nav-cancel-edit-btn": _("Cancel"),
		"nav-apply-edit-btn": _("Save Changes"),
	};
	for (let [id, text] of Object.entries(title_map)) {
		var elem = document.getElementById(id);
		if (elem) elem.title = text;
	}

	// Search bar placeholder
	var search_bar = document.getElementById("search-bar");
	if (search_bar) {
		search_bar.title = _("Prepend * to fuzzy search");
		search_bar.placeholder = _("Search in Directory");
	}

	// Column headers (list view)
	var header_map = {
		"sort-name-btn": _("Name"),
		"sort-mode-btn": _("Mode"),
		"sort-owner-btn": _("Owner"),
		"sort-group-btn": _("Group"),
		"sort-size-btn": _("Size"),
		"sort-modified-btn": _("Modified"),
		"sort-created-btn": _("Created"),
	};
	for (let [id, text] of Object.entries(header_map)) {
		var elem = document.getElementById(id);
		if (elem) {
			// Preserve sort arrow icons, replace only text node
			var icon = elem.querySelector("i");
			elem.textContent = text;
			if (icon) elem.appendChild(icon);
		}
	}

	// Property labels in edit panel
	var property_keys = document.querySelectorAll(".nav-property-pair-key");
	var key_translations = {
		"Name": _("Name"),
		"Owner": _("Owner"),
		"Group": _("Group"),
		"Mode": _("Mode"),
	};
	property_keys.forEach((el) => {
		if (key_translations[el.textContent]) {
			el.textContent = key_translations[el.textContent];
		}
	});

	// Permissions grid labels
	var grid_labels = {
		"Read": _("Read"),
		"Write": _("Write"),
		"Execute": _("Execute"),
		"Owner": _("Owner"),
		"Group": _("Group"),
		"Other": _("Other"),
	};
	document.querySelectorAll(".grid-label").forEach((el) => {
		if (grid_labels[el.textContent]) {
			el.textContent = grid_labels[el.textContent];
		}
	});

	// Toggle labels
	document.querySelectorAll('label[title="Show Hidden Files"]').forEach((el) => {
		el.title = _("Show Hidden Files");
	});
	document.querySelectorAll('label[title="Toggle Dark/Light"]').forEach((el) => {
		el.title = _("Toggle Dark/Light");
	});
}

async function load_locale() {
	var lang = null;
	var match = document.cookie.match(/(?:^|;\s*)CockpitLang=([a-zA-Z_]+)/);
	if (match) {
		lang = match[1];
	}
	if (!lang && cockpit.language && cockpit.language !== "en") {
		lang = cockpit.language;
	}
	if (lang && lang !== "en" && /^[a-zA-Z_]+$/.test(lang)) {
		try {
			var mod = await import("./po." + lang + ".js");
			mod.default(cockpit);
		} catch (e) {
			console.warn("Could not load translations for " + lang, e);
		}
	}
}

async function main() {
	await load_locale();
	set_last_theme_state();
	listen_storage_changes();
	translate_html();
	load_hidden_file_state(nav_window);
	load_item_display_state(nav_window);
	var get_users = nav_window.get_system_users();
	var get_groups = nav_window.get_system_groups();
	var refresh = nav_window.refresh();
	await get_users;
	await get_groups;
	await refresh;
	set_up_buttons();
}

main();
