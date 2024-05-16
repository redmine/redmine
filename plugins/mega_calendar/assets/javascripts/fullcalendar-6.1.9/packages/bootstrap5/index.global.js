/*!
FullCalendar Bootstrap 5 Plugin v6.1.9
Docs & License: https://fullcalendar.io/docs/bootstrap5
(c) 2023 Adam Shaw
*/
FullCalendar.Bootstrap5 = (function (exports, core, internal$1) {
    'use strict';

    class BootstrapTheme extends internal$1.Theme {
    }
    BootstrapTheme.prototype.classes = {
        root: 'fc-theme-bootstrap5',
        tableCellShaded: 'fc-theme-bootstrap5-shaded',
        buttonGroup: 'btn-group',
        button: 'btn btn-primary',
        buttonActive: 'active',
        popover: 'popover',
        popoverHeader: 'popover-header',
        popoverContent: 'popover-body',
    };
    BootstrapTheme.prototype.baseIconClass = 'bi';
    BootstrapTheme.prototype.iconClasses = {
        close: 'bi-x-lg',
        prev: 'bi-chevron-left',
        next: 'bi-chevron-right',
        prevYear: 'bi-chevron-double-left',
        nextYear: 'bi-chevron-double-right',
    };
    BootstrapTheme.prototype.rtlIconClasses = {
        prev: 'bi-chevron-right',
        next: 'bi-chevron-left',
        prevYear: 'bi-chevron-double-right',
        nextYear: 'bi-chevron-double-left',
    };
    // wtf
    BootstrapTheme.prototype.iconOverrideOption = 'buttonIcons'; // TODO: make TS-friendly
    BootstrapTheme.prototype.iconOverrideCustomButtonOption = 'icon';
    BootstrapTheme.prototype.iconOverridePrefix = 'bi-';

    var css_248z = ".fc-theme-bootstrap5 a:not([href]){color:inherit;text-decoration:inherit}.fc-theme-bootstrap5 .fc-list,.fc-theme-bootstrap5 .fc-scrollgrid,.fc-theme-bootstrap5 td,.fc-theme-bootstrap5 th{border:1px solid var(--bs-gray-400)}.fc-theme-bootstrap5 .fc-scrollgrid{border-bottom-width:0;border-right-width:0}.fc-theme-bootstrap5-shaded{background-color:var(--bs-gray-200)}";
    internal$1.injectStyles(css_248z);

    var plugin = core.createPlugin({
        name: '@fullcalendar/bootstrap5',
        themeClasses: {
            bootstrap5: BootstrapTheme,
        },
    });

    var internal = {
        __proto__: null,
        BootstrapTheme: BootstrapTheme
    };

    core.globalPlugins.push(plugin);

    exports.Internal = internal;
    exports["default"] = plugin;

    Object.defineProperty(exports, '__esModule', { value: true });

    return exports;

})({}, FullCalendar, FullCalendar.Internal);
