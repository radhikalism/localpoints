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

Ext.define('Feature', {
    extend: 'Ext.data.Model',
    idgen: 'uuid',
    fields: [
        {name: 'id', type: 'string'},
        {name: 'name', type: 'string', defaultValue: 'Feature'},
        {name: 'type', type: 'string'},
        {name: 'created', type: 'date'},
        {name: 'updated', type: 'date'}
    ],
    proxy: { type: 'memory', id: 'localpoints-layerfeatures' }
})

DEFAULT_PROJ = new OpenLayers.Projection('EPSG:4326')
OSM_PROJ = new OpenLayers.Projection('EPSG:900913')
OSM_GEO_JSON = new OpenLayers.Format.GeoJSON({internalProjection: OSM_PROJ, externalProjection: DEFAULT_PROJ})

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
        button.toggle(false, true)

enableToolbox = () ->
    buttons = Ext.getCmp('tools-panel').query('button')
    for button in buttons
        button.enable()

deleteLayer = (layerStore, featureStore, vectorLayer, tools) ->
    if (CurrentLayer.record != null)
        layerStore.remove(CurrentLayer.record)
        CurrentLayer.record = null
        disableToolbox()
        vectorLayer.removeAllFeatures()
        useNoTool(tools)
        layerStore.sync()
        if (layerStore.count() == 0)
            Ext.getCmp('layerDeleteButton').blur().disable()

handleNewLayerRequest = (button, event, layerStore) ->
    date = new Date()
    layerStore.add(layerStore.create({name: 'Untitled', features: '', created: date, updated: date}))
    layerStore.sync()

handleLayerRowSelectRequest = (selection, record, opts, featureStore, vectorLayer) ->
    vectorLayer.removeAllFeatures()
    enableToolbox()
    if (Ext.getCmp('layerDeleteButton').isDisabled())
        Ext.getCmp('layerDeleteButton').enable()
    if (record.length > 0)
        CurrentLayer.record = record[0]
        geojson = record[0].get('features')
        if (geojson != '')
            features = OSM_GEO_JSON.read(geojson)
            vectorLayer.addFeatures(features)

saveCurrentLayerFeatures = (features) ->
    if (CurrentLayer.record != undefined and CurrentLayer.record != null and features.length > 0)
        geojson = OSM_GEO_JSON.write(features)
        CurrentLayer.record.set('features', geojson)
        CurrentLayer.record.save()

initEditableMap = (map, baseLayer, vectorLayer, tools, zoomToExtent) ->
    map.addLayer(baseLayer)
    map.setBaseLayer(baseLayer)
    map.addLayer(vectorLayer)
    save = (e) -> saveCurrentLayerFeatures(vectorLayer.features)
    vectorLayer.events.register('featureadded', null, save)
    vectorLayer.events.register('featureremoved', null, save)
    vectorLayer.events.register('featuremodified', null, save)
    for name, control of tools
        map.addControl(control)
    map.zoomToExtent(zoomToExtent)
    return map

initBasicRestrictedEditableMap = (id, vectorLayer, tools, zoomToExtent) ->
    options = { restrictedExtent: zoomToExtent }
    map = new OpenLayers.Map(id, options)
    osm = new OpenLayers.Layer.OSM()
    return initEditableMap(map, osm, vectorLayer, tools, zoomToExtent)

initEditorLayout = (layerStore, featureStore, vectorLayer, tools, zoomToExtent) ->

    layersToolbar = {
        tbar: [
            { text: 'New', handler: (b, e) -> handleNewLayerRequest(b, e, layerStore) },
            {
                text: 'Delete',
                id: 'layerDeleteButton',
                focusOnToFront: false,
                enableToggle: false,
                disabled: true,
                listeners: {click: () -> deleteLayer(layerStore, featureStore, vectorLayer, tools)}
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
        store: layerStore,
        listeners: {
            selectionchange: (m, r, o) -> handleLayerRowSelectRequest(m, r, o, featureStore, vectorLayer)
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
        store: featureStore,
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
                        toggleHandler: (button, state) -> if (state) then usePointTool(tools) else useNoTool(tools)
                    },
                    {
                        xtype: 'button',
                        disabled: true,
                        text: 'Line',
                        enableToggle: true,
                        toggleGroup: 'toolbox',
                        toggleHandler: (button, state) -> if (state) then useLineTool(tools) else useNoTool(tools)
                    },
                    {
                        xtype: 'button',
                        disabled: true,
                        text: 'Polygon',
                        enableToggle: true,
                        toggleGroup: 'toolbox',
                        toggleHandler: (button, state) -> if (state) then usePolygonTool(tools) else useNoTool(tools)
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
                        toggleHandler: (button, state) -> if (state) then usePathTool(tools) else useNoTool(tools)
                    },
                    {
                        xtype: 'button',
                        disabled: true,
                        text: 'Rotate',
                        enableToggle: true,
                        toggleGroup: 'toolbox',
                        toggleHandler: (button, state) -> if (state) then useRotateTool(tools) else useNoTool(tools)
                    },
                    {
                        xtype: 'button',
                        disabled: true,
                        text: 'Resize',
                        enableToggle: true,
                        toggleGroup: 'toolbox',
                        toggleHandler: (button, state) -> if (state) then useResizeTool(tools) else useNoTool(tools)
                    },
                    {
                        xtype: 'button',
                        disabled: true,
                        text: 'Move',
                        enableToggle: true,
                        toggleGroup: 'toolbox',
                        toggleHandler: (button, state) -> if (state) then useMoveTool(tools) else useNoTool(tools)
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


initEditor = (layerStore, featureStore) ->
    layerStore.load()
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

    extent = new OpenLayers.Bounds(174.6, -37, 175, -36.8).transform(DEFAULT_PROJ, OSM_PROJ)

    initEditorLayout(layerStore, featureStore, vectors, tools, extent)

Ext.onReady(() ->
    layerStore = Ext.create('Ext.data.Store', {
        model: 'Layer',
    })
    featureStore = Ext.create('Ext.data.Store', {
        model: 'Feature'
    })
    initEditor(layerStore, featureStore)
)
