
function branchGraph(holder, commits_hash) {

    var LEFT_PADDING = 3,
        TOP_PADDING = 10,
        XSTEP = YSTEP = 20;

    var commits_by_scmid = $H(commits_hash),
        commits = commits_by_scmid.values();

    // init max dimensions
    var max_rdmid = max_space = 0;
    commits.each(function(commit) {

        max_rdmid = Math.max(max_rdmid, commit.rdmid);
        max_space = Math.max(max_space, commit.space);
    });

    var graph_height = max_rdmid * YSTEP + YSTEP,
        graph_width = max_space * XSTEP + XSTEP;

    // init colors
    var colors = ['#000'];
    for (var k = 0; k < max_space; k++) {
        colors.push(Raphael.getColor());
    }

    // create graph
    var graph = Raphael(holder, graph_width, graph_height),
        top = graph.set();

    var parent_commit;
    var x, y, parent_x, parent_y;
    var path, longrefs, shortrefs, label, labelBBox;

    commits.each(function(commit) {

        y = TOP_PADDING + YSTEP *(max_rdmid - commit.rdmid);
        x = LEFT_PADDING + XSTEP * commit.space;

        graph.circle(x, y, 3).attr({fill: colors[commit.space], stroke: 'none'});

        // title
        if (commit.refs != null && commit.refs != '') {
            longrefs  = commit.refs;
            shortrefs = longrefs.length > 15 ? longrefs.substr(0, 13) + '...' : longrefs;

            label = graph.text(x + 5, y + 5, shortrefs)
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
                parent_y = TOP_PADDING + YSTEP * (max_rdmid - parent_commit.rdmid);
                parent_x = LEFT_PADDING + XSTEP * parent_commit.space;

                if (parent_commit.space == commit.space) {
                    // vertical path
                    path = graph.path([
                        'M', x, y,
                        'V', parent_y]);
                } else {
                    // path to a commit in a different branch (Bezier curve)
                    path = graph.path([
                        'M', x, y,
                        'C', x, y, x, y + (parent_y - y) / 2, x + (parent_x - x) / 2, y + (parent_y - y) / 2,
                        'C', x + (parent_x - x) / 2, y + (parent_y - y) / 2, parent_x, parent_y-(parent_y-y)/2, parent_x, parent_y]);
                }
            } else {
                // vertical path ending at the bottom of the graph
                path = graph.path([
                    'M', x, y,
                    'V', graph_height]);
            }
            path.attr({stroke: colors[commit.space], "stroke-width": 1.5});
        });

        top.push(graph.circle(x, y, 10)
            .attr({
                fill: '#000',
                opacity: 0,
                cursor: 'pointer',
                href: commit.href})
            .hover(function () {}, function () {}));
    });

    top.toFront();
};
