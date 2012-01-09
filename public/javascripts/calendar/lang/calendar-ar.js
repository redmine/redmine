// Calendar AR language
// Author: SmartData.com.sa
// Encoding: any
// Distributed under the same terms as the calendar itself.

// For translators: please use UTF-8 if possible.  We strongly believe that
// Unicode is the answer to a real internationalized world.  Also please
// include your contact information in the header, as can be seen above.

// full day names
Calendar._DN = new Array
("الاحد",
 "الاثنين",
 "الثلاثاء",
 "الاربعاء",
 "الخميس",
 "الجمعة",
 "السبت",
 "الاحد");

// Please note that the following array of short day names (and the same goes
// for short month names, _SMN) isn't absolutely necessary.  We give it here
// for exemplification on how one can customize the short day names, but if
// they are simply the first N letters of the full name you can simply say:
//
//   Calendar._SDN_len = N; // short day name length
//   Calendar._SMN_len = N; // short month name length
//
// If N = 3 then this is not needed either since we assume a value of 3 if not
// present, to be compatible with translation files that were written before
// this feature.

// short day names
Calendar._SDN = new Array
("أح",
 "إث",
 "ث",
 "أر",
 "خ",
 "ج",
 "س",
 "أح");

// First day of the week. "0" means display Sunday first, "1" means display
// Monday first, etc.
Calendar._FD = 0;

// full month names
Calendar._MN = new Array
("كانون الثاني",
 "شباط",
 "حزيران",
 "آذار",
 "أيار",
 "نيسان",
 "تموز",
 "آب",
 "أيلول",
 "تشرين الاول",
 "تشرين الثاني",
 "كانون الاول");

// short month names
Calendar._SMN = new Array
("كانون الثاني",
 "شباط",
 "حزيران",
 "آذار",
 "أيار",
 "نيسان",
 "تموز",
 "آب",
 "أيلول",
 "تشرين الاول",
 "تشرين الثاني",
 "كانون الاول");

// tooltips
Calendar._TT = {};
Calendar._TT["INFO"] = "حول التقويم";

Calendar._TT["ABOUT"] =
"اختيار الوقت والتاريخ\n" +
"(c) dynarch.com 2002-2005 / Author: Mihai Bazon\n" + // don't translate this this ;-)
"For latest version visit: http://www.dynarch.com/projects/calendar/\n" +
"Distributed under GNU LGPL.  See http://gnu.org/licenses/lgpl.html for details." +
"\n\n" +
"اختيار التاريخ:\n" +
"- استخدم هذه الازرار \xab, \xbb لاختيار السنة\n" +
"- استخدم هذه الازرار " + String.fromCharCode(0x2039) + ", " + String.fromCharCode(0x203a) + " لاختيار الشهر\n" +
"- استمر في النقر فوق الازرار للتظليل السريع.";
Calendar._TT["ABOUT_TIME"] = "\n\n" +
"اختيار الوقت:\n" +
"- انقر على اي جزء من اجزاء الوقت لزيادته\n" +
"-  لانقاصهShiftاو انقر مع الضغط على مفتاح  \n" +
"- او انقر واسحب للتظليل السريع.";

Calendar._TT["PREV_YEAR"] = "السنة السابقة";
Calendar._TT["PREV_MONTH"] = "الشهر السابق";
Calendar._TT["GO_TODAY"] = "اذهب لليوم";
Calendar._TT["NEXT_MONTH"] = "الشهر القادم";
Calendar._TT["NEXT_YEAR"] = "السنة القادمة";
Calendar._TT["SEL_DATE"] = "اختر التاريخ";
Calendar._TT["DRAG_TO_MOVE"] = "اسحب للتتحرك";
Calendar._TT["PART_TODAY"] = "اليوم";

// the following is to inform that "%s" is to be the first day of week
// %s will be replaced with the day name.
Calendar._TT["DAY_FIRST"] = " اولا%sاعرض ";

// This may be locale-dependent.  It specifies the week-end days, as an array
// of comma-separated numbers.  The numbers are from 0 to 6: 0 means Sunday, 1
// means Monday, etc.
Calendar._TT["WEEKEND"] = "5,6";

Calendar._TT["CLOSE"] = "مغلق";
Calendar._TT["TODAY"] = "اليوم";
Calendar._TT["TIME_PART"] = "انقر او اسحب لتغير القيمة";

// date formats
Calendar._TT["DEF_DATE_FORMAT"] = "%Y-%m-%d";
Calendar._TT["TT_DATE_FORMAT"] = "%a, %b %e";

Calendar._TT["WK"] = "رقم الاسبوع";
Calendar._TT["TIME"] = "الوقت:";
