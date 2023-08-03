var EasyToggler = new function() {
  // EasyToggler storage store object where key is ID of container and value is 0 - for hidden default state or 1 - for shown default state
  // Example:
  // localStorage # => {"easy-toggle-state": {myDiv: 0, history: 1}} # where myDiv is by default hidden, and now will be shown as visible and history is vice versa

  var storage = JSON.parse(localStorage.getItem('easy-toggle-state') || "{}");

  var save = function() {
    localStorage.setItem('easy-toggle-state', JSON.stringify(storage));
    return storage;
  };

  var isHidden = function(el) {
    return (el && el.style.display === 'none')
  };

  var toggle = function(el) {
    var parent = el.parentNode;

    parent.classList.toggle("collapsed");

    el.style.display = isHidden(el) ? 'block' : 'none';
    el.id && !!parent.dataset.toggle && save();
    $( document ).trigger( "erui_interface_change_vertical" ); // <> !#@!
    return el;
  };

  // Toggle specify element OR this - which is toggler button so toggle element is sibling
  this.toggle = function(id_or_el, event) {
    if (event && event.target.tagName === "A")
      return;

    var el = (typeof(id_or_el) === "object") ? id_or_el : document.getElementById(id_or_el);
    var id = el.id;
    if (id) {
      if (!!storage[id]) {
        delete storage[id];
      } else {
        storage[id] = isHidden(el) ? 0 : 1;
      }
    }
    toggle(el);
  };

  this.ensureToggle = function() {
    var list = document.querySelectorAll('*[data-toggle]');
    for (var i = 0; i < list.length; ++i) {
      var item = list.item(i);
      var container = document.getElementById(item.dataset.toggle);
      if (!!storage[item.dataset.toggle]) {
        toggle(container);
      }
    }
    return this;
  };
};

$(document).ready(EasyToggler.ensureToggle);
