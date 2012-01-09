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
Calendar._TT["معلومات"] = "حول التقويم";

Calendar._TT["حول"] =
"اختيار الوقت والتاريخ\n" +
"\n\n" +
"اختيار التاريخ:\n" +
"- استخدم هذه الازرار \xab, \xbb لاختيار السنة\n" +
"- استخدم هذه الازرار " + String.fromCharCode(0x2039) + ", " + String.fromCharCode(0x203a) + " لاختيار الشهر\n" +
"- استمر في النقر فوق الازرار للتظليل السريع.";
Calendar._TT["حول_الوقت"] = "\n\n" +
"اختيار الوقت:\n" +
"- انقر على اي جزء من اجزاء الوقت لزيادته\n" +
"-  لانقاصهShiftاو انقر مع الضغط على مفتاح  \n" +
"- او انقر واسحب للتظليل السريع.";

Calendar._TT["السنة_السابقة"] = "السنة السابقة";
Calendar._TT["الشهر_السابق"] = "الشهر السابق";
Calendar._TT["اذهب_اليوم"] = "اذهب لليوم";
Calendar._TT["الشهر_القادم"] = "الشهر القادم";
Calendar._TT["السنة_القادمة"] = "السنة القادمة";
Calendar._TT["اختر_التاريخ"] = "اختر التاريخ";
Calendar._TT["اسحب_تظليل"] = "اسحب للتتحرك";
Calendar._TT["جزء_يوم"] = "اليوم";

// the following is to inform that "%s" is to be the first day of week
// %s will be replaced with the day name.
Calendar._TT["اول_يوم"] = " اولا%sاعرض ";

// This may be locale-dependent.  It specifies the week-end days, as an array
// of comma-separated numbers.  The numbers are from 0 to 6: 0 means Sunday, 1
// means Monday, etc.
Calendar._TT["نهاية الاسبوع"] = "5,6";

Calendar._TT["مغلق"] = "مغلق";
Calendar._TT["اليوم"] = "اليوم";
Calendar._TT["جزء_اليوم"] = "انقر او اسحب لتغير القيمة";

// date formats
Calendar._TT["تنسيق تاريخ"] = "%Y-%m-%d";
Calendar._TT["تنسيق وقت"] = "%a, %b %e";

Calendar._TT["رقم الاسبوع"] = "رقم الاسبوع";
Calendar._TT["الوقت"] = "الوقت:";
