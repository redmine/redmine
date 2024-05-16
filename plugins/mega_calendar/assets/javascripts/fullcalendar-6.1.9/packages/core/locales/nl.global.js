/*!
FullCalendar Core v6.1.9
Docs & License: https://fullcalendar.io
(c) 2023 Adam Shaw
*/
(function (index_js) {
    'use strict';

    var locale = {
        code: 'nl',
        week: {
            dow: 1,
            doy: 4, // The week that contains Jan 4th is the first week of the year.
        },
        buttonText: {
            prev: 'Vorige',
            next: 'Volgende',
            today: 'Vandaag',
            year: 'Jaar',
            month: 'Maand',
            week: 'Week',
            day: 'Dag',
            list: 'Agenda',
        },
        allDayText: 'Hele dag',
        moreLinkText: 'extra',
        noEventsText: 'Geen evenementen om te laten zien',
    };

    index_js.globalLocales.push(locale);

})(FullCalendar);
