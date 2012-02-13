var revisionGraph = null;

function drawRevisionGraph(holder, commits_hash, graph_space) {

    var XSTEP = 20,
        CIRCLE_INROW_OFFSET = 10;

    var commits_by_scmid = $H(commits_hash),
        commits = commits_by_scmid.values();

    var max_rdmid = commits.length - 1;

    var commit_table_rows = $$('table.changesets tr.changeset');

    // create graph
    if(revisionGraph != null)
        revisionGraph.clear();
    else
        revisionGraph = Raphael(holder);

    var top = revisionGraph.set();

    // init dimensions
    var graph_offset = $(holder).getLayout().get('top'),
        graph_width = (graph_space + 1) * XSTEP,
        graph_height = commit_table_rows[max_rdmid].getLayout().get('top') + commit_table_rows[max_rdmid].getLayout().get('height') - graph_offset;

    revisionGraph.setSize(graph_width, graph_height);

    // init colors
    var colors = [];
    Raphael.getColor.reset();
    for (var k = 0; k <= graph_space; k++) {
        colors.push(Raphael.getColor());
    }

    var parent_commit;
    var x, y, parent_x, parent_y;
    var path, longrefs, shortrefs, label, labelBBox;

    commits.each(function(commit) {

        y = commit_table_rows[max_rdmid - commit.rdmid].getLayout().get('top') - graph_offset + CIRCLE_INROW_OFFSET;
        x = XSTEP / 2 + XSTEP * commit.space;

        revisionGraph.circle(x, y, 3).attr({fill: colors[commit.space], stroke: 'none'});

        // title
        if (commit.refs != null && commit.refs != '') {
            longrefs  = commit.refs;
            shortrefs = longrefs.length > 15 ? longrefs.substr(0, 13) + '...' : longrefs;

            label = revisionGraph.text(x + 5, y + 5, shortrefs)
                .attr({
                    font: '12px Fontin-Sans, Arial',
                    fill: '#666',
                    title: longrefs,
                    cursor: 'pointer',
                    rotation: '0'});

            labelBBox = label.getBBox();
            label.translate(labelBBox.width / 2, -labelBBox.height / 3);
        }

        // paths to parents
        commit.parent_scmids.each(function(parent_scmid) {
            parent_commit = commits_by_scmid.get(parent_scmid);

            if (parent_commit) {
                parent_y = commit_table_rows[max_rdmid - parent_commit.rdmid].getLayout().get('top') - graph_offset + CIRCLE_INROW_OFFSET;
                parent_x = XSTEP / 2 + XSTEP * parent_commit.space;

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
                    'V', graph_height]);
            }
            path.attr({stroke: colors[commit.space], "stroke-width": 1.5});
        });

        top.push(revisionGraph.circle(x, y, 10)
            .attr({
                fill: '#000',
                opacity: 0,
                cursor: 'pointer',
                href: commit.href})
            .hover(function () {}, function () {}));
    });

    top.toFront();
};
