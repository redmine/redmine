(function($) {
  'use strict';
  /* set true to enable static sidebar */
  var activeStaticSidebar = false;

  // Wait for document ready
  $(document).ready(function() {
    // Add menu elements
    if (!activeStaticSidebar) {
      addElements();
    }
    
    // Add logo
    addLogo();
    
    // Set quick search margin
    $("#quick-search form").css('margin-right', $("#s2id_project_quick_jump_box").width() + 60);
    $('input[name$="q"]').attr('placeholder', 'Enter Search Text');
    
    if (activeStaticSidebar) {
      $("#wrapper3").css("margin-left", "215px");
      $("#quick-search").css("left", "200px");
      $("#top-menu").css({
        "left": "0",
        "width": "215px",
        "transition": "none"
      });
      $("#quick-search").css("transition", "none");
    }
  });

  function addElements() {
    $('<div id="menu"><div class="burger"><div class="one"></div><div class="two"></div><div class="three"></div></div><div class="circle"></div></div>').insertBefore($("#top-menu"));
    
    var menuLeft = document.getElementById('top-menu'),
        showLeft = document.getElementById('menu'),
        body = document.body,
        search = document.getElementById('quick-search'),
        menuButton = document.getElementById('menu');

    showLeft.onclick = function() {
      $(this).toggleClass('active');
      $(body).toggleClass('menu-push-toright');
      $(menuButton).toggleClass('menu-push-toright');
      if (search != null) {
        $(search).toggleClass('menu-push-toright');
      }
      $(menuLeft).toggleClass('open');
    };
  }

  function addLogo() {
    $("#loggedas").prepend("<div class='redmine-logo'></div>");
  }

  // Close menu when clicking outside
  $(document).on("click", "#main, #header", function() {
    $("#top-menu").removeClass("open");
    $(".menu-push-toright").removeClass("menu-push-toright");
  });

  // Handle error cases
  window.onerror = function myErrorFunction(message, url, linenumber) {
    if (location.href.indexOf("/dmsf") != -1 || location.href.indexOf("/master_backlog") != -1) {
      addLogo();
      if (!activeStaticSidebar) {
        addElements();
      }
    }
  };

  // Remove media query rules for better mobile support
  function removeRule() {
    if (typeof window.CSSMediaRule !== "function") return false;

    var s = document.styleSheets, r, i, j, k;

    if (!s) return false;

    for (i = 0; i < s.length; i++) {
      r = s[i].cssRules;
      if (!r) continue;

      for (j = 0; j < r.length; j++) {
        if (r[j] instanceof CSSMediaRule &&
            r[j].media.mediaText == "screen and (max-width: 899px)") {
          for (k = 0; k < r[j].cssRules.length; k++) {
            r[j].deleteRule(r[j].cssRules[k]);
          }
          return true;
        }
      }
    }
  }
  
  removeRule();
})(jQuery);
