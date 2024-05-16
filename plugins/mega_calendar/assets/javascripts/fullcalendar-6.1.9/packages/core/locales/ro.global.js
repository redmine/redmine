/*!
FullCalendar Core v6.1.9
Docs & License: https://fullcalendar.io
(c) 2023 Adam Shaw
*/
(function (index_js) {
    'use strict';

    var locale = {
        code: 'ro',
        week: {
            dow: 1,
            doy: 7, // The week that contains Jan 1st is the first week of the year.
        },
        buttonText: {
            prev: 'precedentă',
            next: 'următoare',
            today: 'Azi',
            year: 'An',
            month: 'Lună',
            week: 'Săptămână',
            day: 'Zi',
            list: 'Agendă',
        },
        weekText: 'Săpt',
        allDayText: 'Toată ziua',
        moreLinkText(n) {
            return '+alte ' + n;
        },
        noEventsText: 'Nu există evenimente de afișat',
    };

    index_js.globalLocales.push(locale);

})(FullCalendar);
