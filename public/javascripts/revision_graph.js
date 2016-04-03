/* Redmine - project management software
   Copyright (C) 2006-2016  Jean-Philippe Lang */

var revisionGraph = null;

function drawRevisionGraph(holder, commits_hash, graph_space) {
    var XSTEP = 20,
        CIRCLE_INROW_OFFSET = 10;
    var commits_by_scmid = commits_hash,
        commits = $.map(commits_by_scmid, function(val,i){return val;});
    var max_rdmid = commits.length - 1;
    var commit_table_rows = $('table.changesets tr.changeset');

    // create graph
    if(revisionGraph != null)
        revisionGraph.clear();
    else
        revisionGraph = Raphael(holder);

    var top = revisionGraph.set();
    // init dimensions
    var graph_x_offset = commit_table_rows.first().find('td').first().position().left - $(holder).position().left,
        graph_y_offset = $(holder).position().top,
        graph_right_side = graph_x_offset + (graph_space + 1) * XSTEP,
        graph_bottom = commit_table_rows.last().position().top + commit_table_rows.last().height() - graph_y_offset;


    var yForRow = function (index, commit) {
      var row = commit_table_rows.eq(index);

      switch (row.find("td:first").css("vertical-align")) {
        case "middle":
          return row.position().top + (row.height() / 2) - graph_y_offset;
        default:
          return row.position().top + - graph_y_offset + CIRCLE_INROW_OFFSET;
      }
    };

    revisionGraph.setSize(graph_right_side, graph_bottom);

    // init colors
    var colors = [];
    Raphael.getColor.reset();
    for (var k = 0; k <= graph_space; k++) {
        colors.push(Raphael.getColor());
    }

    var parent_commit;
    var x, y, parent_x, parent_y;
    var path, title;
    var revision_dot_overlay;
    $.each(commits, function(index, commit) {
        if (!commit.hasOwnProperty("space"))
            commit.space = 0;

        y = yForRow(max_rdmid - commit.rdmid);
        x = graph_x_offset + XSTEP / 2 + XSTEP * commit.space;
        revisionGraph.circle(x, y, 3)
            .attr({
                fill: colors[commit.space],
                stroke: 'none'
            }).toFront();
        // paths to parents
        $.each(commit.parent_scmids, function(index, parent_scmid) {
            parent_commit = commits_by_scmid[parent_scmid];
            if (parent_commit) {
                if (!parent_commit.hasOwnProperty("space"))
                    parent_commit.space = 0;

                parent_y = yForRow(max_rdmid - parent_commit.rdmid);
                parent_x = graph_x_offset + XSTEP / 2 + XSTEP * parent_commit.space;
                if (parent_commit.space == commit.space) {
                    // vertical path
                    path = revisionGraph.path([
                        'M', x, y,
                        'V', parent_y]);
                } else {
                    // path to a commit in a different branch (Bezier curve)
                    path = revisionGraph.path([
                        'M', x, y,
                        'C', x, y, x, y + (parent_y - y) / 2, x + (parent_x - x) / 2, y + (parent_y - y) / 2,
                        'C', x + (parent_x - x) / 2, y + (parent_y - y) / 2, parent_x, parent_y-(parent_y-y)/2, parent_x, parent_y]);
                }
            } else {
                // vertical path ending at the bottom of the revisionGraph
                path = revisionGraph.path([
                    'M', x, y,
                    'V', graph_bottom]);
            }
            path.attr({stroke: colors[commit.space], "stroke-width": 1.5}).toBack();
        });
        revision_dot_overlay = revisionGraph.circle(x, y, 10);
        revision_dot_overlay
            .attr({
                fill: '#000',
                opacity: 0,
                cursor: 'pointer', 
                href: commit.href
            });

        if(commit.refs != null && commit.refs.length > 0) {
            title = document.createElementNS(revisionGraph.canvas.namespaceURI, 'title');
            title.appendChild(document.createTextNode(commit.refs));
            revision_dot_overlay.node.appendChild(title);
        }
        top.push(revision_dot_overlay);
    });
    top.toFront();
};
