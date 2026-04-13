var lang = null;
var match = document.cookie.match(/(?:^|;\s*)CockpitLang=([a-zA-Z_]+)/);
if (match) {
    lang = match[1];
}
console.log("Language: " + lang);
if (!lang && navigator.language) {
    lang = navigator.language.replace("-", "_").split("_")[0];
}
if (lang && lang !== "en" && /^[a-zA-Z_]+$/.test(lang)) {
    document.write('\x3Cscript src="po.' + lang + '.js">\x3C/script>');
    console.log("Loaded locale: " + lang);
}
