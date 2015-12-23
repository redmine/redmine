/* Simple Grid Scripts tables with fixed First Row and Line */

// scrolls first line and row with body
// div is this
// row is id of row Ex: g_fr
// line is id of line Ex: g_fl
function g_scroll(div, line, row) {
  document.getElementById(line).style.left = - div.scrollLeft + 'px';
  document.getElementById(row).style.top = - div.scrollTop + 'px';
}

// adjusts width of rows
// bli is the block div
// fri is the first row div
// fli is the first line div
// bdi is the body div
function g_adjust(bli, fri, fli, bdi) {
  var frw = document.getElementById(fri).offsetWidth + "px";
  document.getElementById(bli).style.width = frw
  var fl = document.getElementById(fli).children;
  fl[0].style.width = frw
  var bd = document.getElementById(bdi).children;
  bd[0].style.width = frw

  for (var i = 1; i < fl.length; ++i) {
    s1 = fl[i].offsetWidth;
    s2 = bd[i].offsetWidth;
    if (s1 > s2) {
      bd[i].style.width = s1 + "px"
    } else {
      fl[i].style.width = s2 + "px"
    }
  }
}
