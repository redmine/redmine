var NS4 = (navigator.appName == "Netscape" && parseInt(navigator.appVersion) < 5);

function addOption(theSel, theText, theValue) {
  var newOpt = new Option(theText, theValue);
  var selLength = theSel.length;
  theSel.options[selLength] = newOpt;
}

function swapOptions(theSel, index1, index2) {
  var text, value, selected;
  text = theSel.options[index1].text;
  value = theSel.options[index1].value;
  selected = theSel.options[index1].selected;
  theSel.options[index1].text = theSel.options[index2].text;
  theSel.options[index1].value = theSel.options[index2].value;
  theSel.options[index1].selected = theSel.options[index2].selected;
  theSel.options[index2].text = text;
  theSel.options[index2].value = value;
  theSel.options[index2].selected = selected;
}

function deleteOption(theSel, theIndex) {
  var selLength = theSel.length;
  if (selLength > 0) {
    theSel.options[theIndex] = null;
  }
}

function moveOptions(theSelFrom, theSelTo) {
  var selLength = theSelFrom.length;
  var selectedText = new Array();
  var selectedValues = new Array();
  var selectedCount = 0;
  var i;
  for (i = selLength - 1; i >= 0; i--) {
    if (theSelFrom.options[i].selected) {
      selectedText[selectedCount] = theSelFrom.options[i].text;
      selectedValues[selectedCount] = theSelFrom.options[i].value;
      deleteOption(theSelFrom, i);
      selectedCount++;
    }
  }
  for (i = selectedCount - 1; i >= 0; i--) {
    addOption(theSelTo, selectedText[i], selectedValues[i]);
  }
  if (NS4) history.go(0);
}

function moveOptionUp(theSel) {
  var indexTop = 0;
  for(var s=0; s<theSel.length; s++) {
    if (theSel.options[s].selected) {
      if (s > indexTop) {
        swapOptions(theSel, s-1, s);
      }
      indexTop++;
    }
  }
}

function moveOptionTop(theSel) {
  var indexTop = 0;
  for(var s=0; s<theSel.length; s++) {
    if (theSel.options[s].selected) {
      if (s > indexTop) {
        for (var i=s; i>indexTop; i--) {
          swapOptions(theSel, i-1, i);
        }
      }
      indexTop++;
    }
  }
}

function moveOptionDown(theSel) {
  var indexBottom = theSel.length - 1;
  for(var s=indexBottom; s>=0; s--) {
    if (theSel.options[s].selected) {
      if (s < indexBottom) {
        swapOptions(theSel, s+1, s);
      }
      indexBottom--;
    }
  }
}

function moveOptionBottom(theSel) {
  var indexBottom = theSel.length - 1;
  for(var s=indexBottom; s>=0; s--) {
    if (theSel.options[s].selected) {
      if (s < indexBottom) {
        for (i=s; i<indexBottom; i++) {
          swapOptions(theSel, i+1, i);
        }
      }
      indexBottom--;
    }
  }
}

// OK
function selectAllOptions(id) {
  var select = $('#'+id);
  select.children('option').attr('selected', true);
}
