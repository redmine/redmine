/*!
FullCalendar Moment Timezone Plugin v6.1.9
Docs & License: https://fullcalendar.io/docs/moment-timezone-plugin
(c) 2023 Adam Shaw
*/
FullCalendar.MomentTimezone = (function (exports, core, moment, internal) {
    'use strict';

    function _interopDefault (e) { return e && e.__esModule ? e : { 'default': e }; }

    var moment__default = /*#__PURE__*/_interopDefault(moment);

    class MomentNamedTimeZone extends internal.NamedTimeZoneImpl {
        offsetForArray(a) {
            return moment__default["default"].tz(a, this.timeZoneName).utcOffset();
        }
        timestampToArray(ms) {
            return moment__default["default"].tz(ms, this.timeZoneName).toArray();
        }
    }

    var plugin = core.createPlugin({
        name: '@fullcalendar/moment-timezone',
        namedTimeZonedImpl: MomentNamedTimeZone,
    });

    core.globalPlugins.push(plugin);

    exports["default"] = plugin;

    Object.defineProperty(exports, '__esModule', { value: true });

    return exports;

})({}, FullCalendar, moment, FullCalendar.Internal);
