;(function ($, window, document, undefined) {
    "use strict";

    var pluginName = "entityArray",
        defaults = {
            propertyName: "value"
        };

    function Plugin (element, options) {
        this.element = element;
        this.options = $.extend({}, defaults, options);
        this._defaults = defaults;
        this._name = pluginName;
        this.init();
    }

    Plugin.prototype = {

        init: function () {
            var self = this;
            this.entities = {};
            this.element.addClass("entity-array");
            this.createEmptyInput();

            if (this.options.entities) {
                $.each(this.options.entities, function () {
                    self.add(this);
                });
            }
        },

        add: function (entity) {
            var self = this;

            this.normalizeEntityData(entity);
            if (!entity.id || entity === "" || this.entities[entity.id]) {
                return null;
            }

            entity.element = $("<span/>")
                .text(entity.name)
                .addClass(entity.className || this.options.className)
                .appendTo(this.element)
                .after(" ");

            $("<input/>")
                .attr("type", "hidden")
                .attr("name", this.options.inputNames)
                .val(entity.id)
                .appendTo(entity.element);

            $("<span/>")
                .html('&nbsp;')
                .addClass("icon icon-del")
                .appendTo(entity.element)
                .data("entity-id", entity.id)
                .click(function () {
                    self.removeEntity($(this).data("entity-id"));
                });

            this.entities[entity.id] = entity;

            this.removeEmptyInput();

            return entity;
        },

        removeEntity: function (entityId) {
            var entity = this.entities[entityId];
            entity.element.remove();

            delete this.entities[entityId];

            if (Object.keys(this.entities).length === 0) {
                this.createEmptyInput();
            }

            if (typeof this.options.afterRemove === "function") {
                this.options.afterRemove(entity);
            }
        },

        clear: function () {
            for( var id in this.entities ) {
                this.removeEntity(id);
            }
        },

        getValue: function() {
            return Object.keys(this.entities);
        },

        normalizeEntityData: function (entityData) {
            entityData.id = entityData.id.toString();
            entityData.name = entityData.name.toString();
        },

        createEmptyInput: function () {
            this.emptyInput = $("<input/>")
                .attr("type", "hidden")
                .attr("name", this.options.inputNames)
                .appendTo(this.element);
        },

        removeEmptyInput: function () {
            if (this.emptyInput) {
                this.emptyInput.remove();
                this.emptyInput = null;
            }
        }

    };

    $.fn[pluginName] = function (options, methodAttrs) {
        var value = null;
        this.each(function () {
            var instance = $.data(this, "plugin_" + pluginName);
            if (!instance) {
                $.data(this, "plugin_" + pluginName, new Plugin($(this), options));
            } else  {
                value = instance[options].call(instance, methodAttrs);
            }
        });
        if( value !== null )
            return value;
        else
            return this;
    };

})(jQuery, window, document);
