Ext.Loader.setConfig({enabled:true});
Ext.Loader.setPath('Ext.ux', './js/ux');
Ext.require('Ext.ux.layout.Center');

Ext.define('Layer', {
    extend: 'Ext.data.Model',
    idgen: 'uuid',
    fields: [
        {name: 'id', type: 'string'},
        {name: 'name', type: 'string', defaultValue: 'Untitled'},
        {name: 'features', type: 'string'},
        {name: 'created', type: 'date'},
        {name: 'updated', type: 'date'}
    ],
    proxy: { type: 'localstorage', id: 'localpoints-layers' }
})

FROM_PROJ = new OpenLayers.Projection('EPSG:4326')
OSM_PROJ = new OpenLayers.Projection('EPSG:900913')

Ext.define('CurrentLayer', {
    singleton: true,
    record: null
})

useTool = (selectedControlName, controls) ->
    for name, control of controls
        if (name == selectedControlName)
            control.activate()
        else
            control.deactivate()

usePointTool = (controls) ->
    useTool('point', controls)

useLineTool = (controls) ->
    useTool('line', controls)

usePolygonTool = (controls) ->
    useTool('polygon', controls)

usePathTool = (controls) ->
    controls.modify.mode = OpenLayers.Control.ModifyFeature.RESHAPE;
    useTool('modify', controls)

useRotateTool = (controls) ->
    controls.modify.mode = OpenLayers.Control.ModifyFeature.RESHAPE | OpenLayers.Control.ModifyFeature.ROTATE;
    useTool('modify', controls)

useResizeTool = (controls) ->
    controls.modify.mode = OpenLayers.Control.ModifyFeature.RESHAPE | OpenLayers.Control.ModifyFeature.RESIZE;
    useTool('modify', controls)

useMoveTool = (controls) ->
    controls.modify.mode = OpenLayers.Control.ModifyFeature.RESHAPE | OpenLayers.Control.ModifyFeature.DRAG;
    useTool('modify', controls)

useNoTool = (controls) ->
    for name, control of controls
        control.deactivate()

disableToolbox = () ->
    buttons = Ext.getCmp('tools-panel').query('button')
    for button in buttons
        button.blur()
        button.disable()

enableToolbox = () ->
    buttons = Ext.getCmp('tools-panel').query('button')
    for button in buttons
        button.enable()

deleteLayer = (store) ->
    if (CurrentLayer.record != null)
        store.remove(CurrentLayer.record)
        CurrentLayer.record = null
        disableToolbox()
        useNoTool()
        store.sync()
        if (store.count() == 0)
            Ext.getCmp('layerDeleteButton').blur().disable()

handleNewLayerRequest = (button, event, store) ->
    date = new Date()
    store.add(store.create({name: 'Untitled', features: '', created: date, updated: date}))
    store.sync()

handleLayerRowSelectRequest = (selection, record, opts, store) ->
    CurrentLayer.record = record[0]
    enableToolbox()
    if (Ext.getCmp('layerDeleteButton').isDisabled())
        Ext.getCmp('layerDeleteButton').enable()


initEditableMap = (map, baseLayer, vectorLayer, tools, zoomToExtent) ->
    map.addLayer(baseLayer)
    map.setBaseLayer(baseLayer)
    map.addLayer(vectorLayer)
    for name, control of tools
        map.addControl(control)
    map.zoomToExtent(zoomToExtent)
    return map

initBasicRestrictedEditableMap = (id, vectorLayer, tools, zoomToExtent) ->
    options = { restrictedExtent: zoomToExtent }
    map = new OpenLayers.Map(id, options)
    osm = new OpenLayers.Layer.OSM()
    return initEditableMap(map, osm, vectorLayer, tools, zoomToExtent)

initEditorLayout = (store, vectorLayer, tools, zoomToExtent) ->

    layersToolbar = {
        tbar: [
            { text: 'New', handler: (b, e) -> handleNewLayerRequest(b, e, store) },
            {
                text: 'Delete',
                id: 'layerDeleteButton',
                focusOnToFront: false,
                enableToggle: false,
                disabled: true,
                listeners: {click: () -> deleteLayer(store)}
            }],
        border: false
    }

    layersColumns = [
        {
            id: 'layer-name',
            text: 'Name',
            sortable: true,
            dataIndex: 'name',
            field: { xtype: 'textfield', allowBlank: false }
        },
        {
            id: 'layer-updated',
            text: 'Updated',
            sortable: true,
            dataIndex: 'updated'
        },
        {
            id: 'layer-created',
            text: 'Created',
            sortable: true,
            dataIndex: 'created'
        }
    ]

    layersGrid = {
        xtype: 'gridpanel',
        border: false,
        selType: 'rowmodel',
        plugins: [
            Ext.create('Ext.grid.plugin.CellEditing', {
                clicksToEdit: 2,
                listeners: {
                    edit: { element: 'el', fn: (editor, e) -> e.record.save() }
                }
            })
        ],
        store: store,
        listeners: {
            selectionchange: (m, r, o) -> handleLayerRowSelectRequest(m, r, o, store)
        },
        columns: layersColumns
    }
    
    layersPanel = {
        id: 'layers-panel',
        title: 'Layers',
        region: 'north',
        height: 200,
        autoScroll: true,
        margins: '2 0 2 0',
        items: [layersToolbar, layersGrid]
    }


    featuresToolbar = { tbar: [{ text: 'Delete' }, { text: 'Delete all' }], border: false }

    featuresColumns = [
        {
            id: 'feature-name',
            text: 'Name',
            sortable: true,
            dataIndex: 'name',
            field: { xtype: 'textfield', allowBlank: false }
        },
        {
            id: 'feature-type',
            text: 'Type',
            sortable: true,
            dataIndex: 'type'
        },
        {
            id: 'feature-updated',
            text: 'Updated',
            sortable: true,
            dataIndex: 'updated'
        },
        {
            id: 'feature-created',
            text: 'Created',
            sortable: true,
            dataIndex: 'created'
        }
    ]

    featuresGrid = {
        xtype: 'gridpanel',
        border: false,
        selType: 'rowmodel',
        plugins: [Ext.create('Ext.grid.plugin.CellEditing', {clicksToEdit: 2})],
        columns: featuresColumns
    }

    featuresPanel = {
        id: 'features-panel',
        title: 'Features',
        region: 'center',
        autoScroll: true,
        margins: '2 0 2 0',
        items: [featuresToolbar, featuresGrid],
        }

    drawToolsPanel = {
        id: 'draw-tools-panel',
        title: 'Draw',
        region: 'north',
        border: false,
        layout: 'ux.center',
        widthRatio: 0.80,
        autoHeight: true,
        frame: true,
        items: [
            {
                xtype: 'buttongroup',
                columns: 3,
                defaults: {scale: 'small'},
                items: [
                    {
                        xtype: 'button',
                        disabled: true,
                        text: 'Point',
                        enableToggle: true,
                        toggleGroup: 'toolbox',
                        toggleHandler: (button, state) -> usePointTool(tools) if state
                    },
                    {
                        xtype: 'button',
                        disabled: true,
                        text: 'Line',
                        enableToggle: true,
                        toggleGroup: 'toolbox',
                        toggleHandler: (button, state) -> useLineTool(tools) if state
                    },
                    {
                        xtype: 'button',
                        disabled: true,
                        text: 'Polygon',
                        enableToggle: true,
                        toggleGroup: 'toolbox',
                        toggleHandler: (button, state) -> usePolygonTool(tools) if state
                    }
                ]
            }
        ]
    }

    modifyToolsPanel = {
        id: 'modify-tools-panel',
        title: 'Modify',
        region: 'north',
        border: false,
        layout: 'ux.center',
        widthRatio: 0.80,
        autoHeight: true,
        frame: true,
        items: [
            {
                xtype: 'buttongroup',
                columns: 4,
                defaults: {scale: 'small'},
                items: [
                    {
                        xtype: 'button',
                        disabled: true,
                        text: 'Path',
                        enableToggle: true,
                        toggleGroup: 'toolbox',
                        toggleHandler: (button, state) -> usePathTool(tools) if state
                    },
                    {
                        xtype: 'button',
                        disabled: true,
                        text: 'Rotate',
                        enableToggle: true,
                        toggleGroup: 'toolbox',
                        toggleHandler: (button, state) -> useRotateTool(tools) if state
                    },
                    {
                        xtype: 'button',
                        disabled: true,
                        text: 'Resize',
                        enableToggle: true,
                        toggleGroup: 'toolbox',
                        toggleHandler: (button, state) -> useResizeTool(tools) if state
                    },
                    {
                        xtype: 'button',
                        disabled: true,
                        text: 'Move',
                        enableToggle: true,
                        toggleGroup: 'toolbox',
                        toggleHandler: (button, state) -> useMoveTool(tools) if state
                    }
                ]
            }
        ]
    }



    toolsPanel = {
        id: 'tools-panel',
        title: 'Toolbox',
        region: 'south',
        margins: '2 0 0 0',
        bodyStyle: 'padding: 4px',
        items: [drawToolsPanel, modifyToolsPanel]
    }

    mapPanel = {
        id: 'map-panel',
        region: 'center',
        layout: 'fit',
        margins: '5 5 5 0',
        activeItem: 0,
        border: false,
        items: []
    }

    Ext.create('Ext.Viewport', {
        layout: 'border',
        title: 'localpoints on a map',
        items: [
            {
                xtype: 'box',
                id: 'header',
                region: 'north',
                html: '<h1>localpoints on a map</h1>',
                height: 30
            },
            {
                layout: 'border',
                id: 'layout-browser',
                region: 'west',
                border: false,
                split: true,
                margins: '5 0 5 5',
                width: 300,
                minSize: 160,
                maxSize: 400,
                items: [layersPanel, featuresPanel, toolsPanel]
            },
            mapPanel
        ],
        renderTo: Ext.getBody()
    })
    initBasicRestrictedEditableMap('map-panel-body', vectorLayer, tools, zoomToExtent)


initEditor = (store) ->
    OpenLayers.Feature.Vector.style['default']['strokeWidth'] = '2'

    renderer = OpenLayers.Util.getParameters(window.location.href).renderer
    vectors = new OpenLayers.Layer.Vector("Vector Layer", {
        renderers: if renderer then [renderer] else OpenLayers.Layer.Vector.prototype.renderers
    });

    featureModifier = new OpenLayers.Control.ModifyFeature(vectors)

    tools = {
        point: new OpenLayers.Control.DrawFeature(vectors, OpenLayers.Handler.Point),
        line: new OpenLayers.Control.DrawFeature(vectors, OpenLayers.Handler.Path),
        polygon: new OpenLayers.Control.DrawFeature(vectors, OpenLayers.Handler.Polygon),
        modify: featureModifier
    }

    extent = new OpenLayers.Bounds(174.6, -37, 175, -36.8).transform(FROM_PROJ, OSM_PROJ)

    initEditorLayout(store, vectors, tools, extent)

Ext.onReady(() ->
    layerStore = Ext.create('Ext.data.Store', {
        model: 'Layer',
        autoLoad: true
    })
    initEditor(layerStore)
)
