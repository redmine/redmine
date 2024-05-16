/*!
FullCalendar Core v6.1.9
Docs & License: https://fullcalendar.io
(c) 2023 Adam Shaw
*/
(function (index_js) {
    'use strict';

    var locale = {
        code: 'ar-tn',
        week: {
            dow: 1,
            doy: 4, // The week that contains Jan 4th is the first week of the year.
        },
        direction: 'rtl',
        buttonText: {
            prev: 'السابق',
            next: 'التالي',
            today: 'اليوم',
            year: 'سنة',
            month: 'شهر',
            week: 'أسبوع',
            day: 'يوم',
            list: 'أجندة',
        },
        weekText: 'أسبوع',
        allDayText: 'اليوم كله',
        moreLinkText: 'أخرى',
        noEventsText: 'أي أحداث لعرض',
    };

    index_js.globalLocales.push(locale);

})(FullCalendar);
