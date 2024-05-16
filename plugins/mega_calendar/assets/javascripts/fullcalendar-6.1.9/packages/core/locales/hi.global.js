/*!
FullCalendar Core v6.1.9
Docs & License: https://fullcalendar.io
(c) 2023 Adam Shaw
*/
(function (index_js) {
    'use strict';

    var locale = {
        code: 'hi',
        week: {
            dow: 0,
            doy: 6, // The week that contains Jan 1st is the first week of the year.
        },
        buttonText: {
            prev: 'पिछला',
            next: 'अगला',
            today: 'आज',
            year: 'वर्ष',
            month: 'महीना',
            week: 'सप्ताह',
            day: 'दिन',
            list: 'कार्यसूची',
        },
        weekText: 'हफ्ता',
        allDayText: 'सभी दिन',
        moreLinkText(n) {
            return '+अधिक ' + n;
        },
        noEventsText: 'कोई घटनाओं को प्रदर्शित करने के लिए',
    };

    index_js.globalLocales.push(locale);

})(FullCalendar);
