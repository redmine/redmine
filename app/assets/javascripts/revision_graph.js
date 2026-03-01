/**
 * Redmine - project management software
 * Copyright (C) 2006-  Jean-Philippe Lang
 * This code is released under the GNU General Public License.
 */

var revisionGraph = null;
const SVG_NS = 'http://www.w3.org/2000/svg';
const XLINK_NS = 'http://www.w3.org/1999/xlink';

function createSvgElement(name) {
    return document.createElementNS(SVG_NS, name);
}

function buildRevisionGraph(holder) {
    const svg = createSvgElement('svg');
    const pathsLayer = createSvgElement('g');
    const nodesLayer = createSvgElement('g');
    const overlaysLayer = createSvgElement('g');

    svg.setAttribute('aria-hidden', 'true');
    svg.style.display = 'block';
    svg.style.overflow = 'visible';

    svg.appendChild(pathsLayer);
    svg.appendChild(nodesLayer);
    svg.appendChild(overlaysLayer);

    while (holder.firstChild) {
        holder.removeChild(holder.firstChild);
    }
    holder.appendChild(svg);

    return {
        holder: holder,
        svg: svg,
        pathsLayer: pathsLayer,
        nodesLayer: nodesLayer,
        overlaysLayer: overlaysLayer
    };
}

function clearRevisionGraph(graph) {
    [graph.pathsLayer, graph.nodesLayer, graph.overlaysLayer].forEach(layer => layer.replaceChildren());
}

function setRevisionGraphSize(graph, width, height) {
    const graphWidth = Math.max(1, Math.ceil(width));
    const graphHeight = Math.max(1, Math.ceil(height));

    graph.svg.setAttribute('width', graphWidth);
    graph.svg.setAttribute('height', graphHeight);
    graph.svg.setAttribute('viewBox', '0 0 ' + graphWidth + ' ' + graphHeight);
}

function drawPath(graph, pathData, attrs) {
    const path = createSvgElement('path');
    const d = pathData.map(function(item) { return String(item); }).join(' ');

    path.setAttribute('d', d);
    Object.keys(attrs).forEach(function(name) {
        path.setAttribute(name, String(attrs[name]));
    });
    graph.pathsLayer.appendChild(path);
}

function drawCircle(layer, x, y, r, attrs) {
    const circle = createSvgElement('circle');

    circle.setAttribute('cx', String(x));
    circle.setAttribute('cy', String(y));
    circle.setAttribute('r', String(r));
    Object.keys(attrs).forEach(function(name) {
        circle.setAttribute(name, String(attrs[name]));
    });
    layer.appendChild(circle);

    return circle;
}

// Generates a distinct, consistent HSL color for each index.
function colorBySpace(index) {
    const hue = (index * 27) % 360;
    const band = Math.floor(index / 14);
    const saturation = Math.max(40, 72 - (band % 3) * 12);
    const lightness = Math.min(56, 42 + (band % 2) * 6);

    return 'hsl(' + hue + ', ' + saturation + '%, ' + lightness + '%)';
}

function drawRevisionGraph(holder, commits_hash, graph_space) {
    var XSTEP = 20,
        CIRCLE_INROW_OFFSET = 10;
    var commits_by_scmid = commits_hash,
        commits = $.map(commits_by_scmid, function(val,i){return val;});
    var max_rdmid = commits.length - 1;
    var commit_table_rows = $('table.changesets tr.changeset');
    if (!revisionGraph || revisionGraph.holder !== holder) {
        revisionGraph = buildRevisionGraph(holder);
    }
    const graph = revisionGraph;
    clearRevisionGraph(graph);

    if (commit_table_rows.length === 0) {
        setRevisionGraphSize(graph, 1, 1);
        return;
    }

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
          return row.position().top - graph_y_offset + CIRCLE_INROW_OFFSET;
        }
    };

    setRevisionGraphSize(graph, graph_right_side, graph_bottom);

    // init colors
    var colors = [];
    for (let k = 0; k <= graph_space; k++) {
        colors.push(colorBySpace(k));
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
        drawCircle(graph.nodesLayer, x, y, 3, {
            fill: colors[commit.space],
            stroke: 'none'
        });

        // check for parents in the same column
        let noVerticalParents = true;
        $.each(commit.parent_scmids, function (index, parentScmid) {
            parent_commit = commits_by_scmid[parentScmid];
            if (parent_commit) {
                if (!parent_commit.hasOwnProperty("space"))
                    parent_commit.space = 0;

                // has parent in the same column on this page
                if (parent_commit.space === commit.space)
                    noVerticalParents = false;
            } else {
                // has parent in the same column on the other page
                noVerticalParents = false;
            }
        });

        // paths to parents
        $.each(commit.parent_scmids, function(index, parent_scmid) {
            parent_commit = commits_by_scmid[parent_scmid];
            if (parent_commit) {
                parent_y = yForRow(max_rdmid - parent_commit.rdmid);
                parent_x = graph_x_offset + XSTEP / 2 + XSTEP * parent_commit.space;
                const controlPointDelta = (parent_y - y) / 8;

                if (parent_commit.space === commit.space) {
                    // vertical path
                    path = [
                        'M', x, y,
                        'V', parent_y];
                } else if (noVerticalParents) {
                    // branch start (Bezier curve)
                    path = [
                        'M', x, y,
                        'C', x, y + controlPointDelta, x, parent_y - controlPointDelta, parent_x, parent_y];
                } else if (!parent_commit.hasOwnProperty('vertical_children')) {
                    // branch end (Bezier curve)
                    path = [
                        'M', x, y,
                        'C', parent_x, y + controlPointDelta, parent_x, parent_y, parent_x, parent_y];
                } else {
                    // path to a commit in a different branch (Bezier curve)
                    path = [
                        'M', x, y,
                        'C', parent_x, y, x, parent_y, parent_x, parent_y];
                }
            } else {
                // vertical path ending at the bottom of the revisionGraph
                path = [
                    'M', x, y,
                    'V', graph_bottom];
            }
            drawPath(graph, path, {stroke: colors[commit.space], 'stroke-width': 1.5, fill: 'none'});
        });

        let overlayLayer = graph.overlaysLayer;
        if (commit.href) {
            overlayLayer = createSvgElement('a');
            overlayLayer.setAttribute('href', commit.href);
            overlayLayer.setAttributeNS(XLINK_NS, 'href', commit.href);
            graph.overlaysLayer.appendChild(overlayLayer);
        }

        revision_dot_overlay = drawCircle(overlayLayer, x, y, 10, {
            fill: '#000',
            opacity: 0,
            cursor: commit.href ? 'pointer' : 'default'
        });

        if(commit.refs != null && commit.refs.length > 0) {
            title = createSvgElement('title');
            title.appendChild(document.createTextNode(commit.refs));
            revision_dot_overlay.appendChild(title);
        }
    });
};
