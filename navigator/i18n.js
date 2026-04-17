/*
	Cockpit Navigator - i18n helper.
	Wraps cockpit.gettext / cockpit.ngettext for use in ES modules.
 */

const _ = cockpit.gettext;
const N_ = function N_(str) { return str; };
const C_ = cockpit.gettext;
const ngettext = cockpit.ngettext;

export { _, N_, C_, ngettext };
