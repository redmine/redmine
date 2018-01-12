$(document).ready(
    function() {
        // Discuss and Announce need to embed iframes
        $("#discussOSBLink").click(function() {
            $("#discussOSB").html('<iframe id="forum_embed_2" src="javascript:void(0)" scrolling="no" frameborder="0" width="100%" height="700"></iframe>');
            document.getElementById("forum_embed_2").src = "https://groups.google.com/forum/embed/?place=forum/osb-discuss&showsearch=true&showpopout=true&parenturl=" + encodeURIComponent(window.location.href);
        });

        $("#announceOSBLink").click(function() {
            $("#announceOSB").html('<iframe id="forum_embed" src="javascript:void(0)" scrolling="no" frameborder="0" width="100%" height="700"></iframe>');
            document.getElementById("forum_embed").src = "https://groups.google.com/forum/embed/?place=forum/osb-announce&showsearch=true&showpopout=true&parenturl=" + encodeURIComponent(window.location.href);
        });

        // Cells
        var subTabCellsList = ['cells_graph', 'cells_list', 'cells_gallery', 'cells_tags'];	
        $("#cellsLink").click(function() {
            for (var i=0; i<subTabCellsList.length; ++i) {
                var tab = subTabCellsList[i];
                (function(tab){
                    $.ajax({
                        url: "/projects/"+tab,
                        async: true,
                        success: function(html){
                            $("#"+tab).html(html);
                        },
                        error: function( xhr, textStatus, errorThrown ) {
                            console.log("Error loading tab: " + textStatus);
                        }
                    });
                })(tab);
            }
        });

        // Other
        var otherTabs = ['technology', 'groups', 'people'];
        for (var i=0; i<otherTabs.length; ++i) {
            $('#' + otherTabs[i] + 'Link').click(function(tab) {
                return function() {
                    $.ajax({
                        url: "/projects/"+tab,
                        async: true,
                        success: function(html){
                            $("#"+tab).html(html);
                        },
                        error: function( xhr, textStatus, errorThrown ) {
                            console.log("Error loading tab: " + textStatus);
                        }
                    });
                }
            }(otherTabs[i]));
        }

        //Read if a new tab is pass as a parameter in the url 	
        var a = location.href.split("#");
        if (a[1] == 'cells'){
            selectedTab = 'cells_list';
        }
        else if (a.length > 1) {
            selectedTab = a[1];
        } else {
            // no parameter, show project highlights
            selectedTab = "projecthighlights";
        }

        if (subTabCellsList.indexOf(selectedTab) > -1){
            $("#cellsLink").trigger("click");
        } else {
            $("#"+selectedTab+"Link").trigger("click");
        }
    });
