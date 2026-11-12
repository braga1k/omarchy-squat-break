// Shared components can render rich text: neutralize markup before crossing them.
function plain(value) {
    return String(value).slice(0, 1024).replace(/&/g, "＆").replace(/</g, "‹").replace(/>/g, "›");
}
