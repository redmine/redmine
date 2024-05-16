/*!
FullCalendar Core v6.1.9
Docs & License: https://fullcalendar.io
(c) 2023 Adam Shaw
*/
(function (index_js) {
    'use strict';

    var locale = {
        code: 'zh-cn',
        week: {
            // GB/T 7408-1994《数据元和交换格式·信息交换·日期和时间表示法》与ISO 8601:1988等效
            dow: 1,
            doy: 4, // The week that contains Jan 4th is the first week of the year.
        },
        buttonText: {
            prev: '上月',
            next: '下月',
            today: '今天',
            year: '年',
            month: '月',
            week: '周',
            day: '日',
            list: '日程',
        },
        weekText: '周',
        allDayText: '全天',
        moreLinkText(n) {
            return '另外 ' + n + ' 个';
        },
        noEventsText: '没有事件显示',
    };

    index_js.globalLocales.push(locale);

})(FullCalendar);
