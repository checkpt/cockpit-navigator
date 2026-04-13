var lang = cockpit.language;
console.log("Language: " + lang);
console.log(lang, lang !== "en", /^[a-zA-Z_]+$/.test(lang));
if (lang && lang !== "en" && /^[a-zA-Z_]+$/.test(lang)) {
    document.write('\x3Cscript src="po.' + lang + '.js">\x3C/script>');
    console.log("Loaded locale: " + lang);
}
