// Логика добавления флажков на карту
// Экспортируем глобальную функцию, чтобы использовать ее в map.js

function initAddMark(map) {
    const flagSource = new ol.source.Vector();
    const flagLayer = new ol.layer.Vector({
        source: flagSource,
        style: new ol.style.Style({
            text: new ol.style.Text({
                text: '🚩',
                font: '24px "Segoe UI Emoji", sans-serif',
                offsetY: -12
            })
        })
    });

    const featureById = new Map();
    let selectedFeature = null;

    const highlightFeature = (feature) => {
        if (selectedFeature) {
            selectedFeature.setStyle(null);
        }
        selectedFeature = feature || null;
        if (selectedFeature) {
            selectedFeature.setStyle(
                new ol.style.Style({
                    text: new ol.style.Text({
                        text: '🚩',
                        font: '34px "Segoe UI Emoji", sans-serif',
                        offsetY: -16
                    })
                })
            );
        }
    };

    map.addLayer(flagLayer);

    const loadExistingMarks = async () => {
        const res = await fetch('/api/marks/');
        if (!res.ok) {
            console.error('Failed to load marks', await res.text());
            return;
        }

        const data = await res.json();
        if (!data || !Array.isArray(data.items)) {
            return;
        }

        data.items.forEach((item) => {
            const coordinate = ol.proj.fromLonLat([item.longitude, item.latitude]);
            const feature = new ol.Feature({
                geometry: new ol.geom.Point(coordinate)
            });
            feature.set('id', item.id);
            featureById.set(item.id, feature);
            flagSource.addFeature(feature);
        });
    };

    loadExistingMarks();

    map.on('click', async (evt) => {
        const clickedFeature = map.forEachFeatureAtPixel(
            evt.pixel,
            (feature, layer) => (layer === flagLayer ? feature : null),
            { layerFilter: (layer) => layer === flagLayer }
        );

        if (clickedFeature) {
            const markId = clickedFeature.get('id');
            if (markId) {
                const res = await fetch('/api/marks/delete/', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ id: markId })
                });
                if (!res.ok) {
                    console.error('Failed to delete mark', await res.text());
                    return;
                }
            }

            flagSource.removeFeature(clickedFeature);
            featureById.delete(markId);
            if (selectedFeature === clickedFeature) {
                highlightFeature(null);
            }
            window.dispatchEvent(new CustomEvent('marks:changed', {
                detail: { action: 'deleted', id: markId }
            }));
            return;
        }

        const lonLat = ol.proj.toLonLat(evt.coordinate);
        const res = await fetch('/api/marks/add/', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ longitude: lonLat[0], latitude: lonLat[1] })
        });

        if (!res.ok) {
            console.error('Failed to add mark', await res.text());
            return;
        }

        const data = await res.json();

        const feature = new ol.Feature({
            geometry: new ol.geom.Point(evt.coordinate)
        });
        if (data && data.id) {
            feature.set('id', data.id);
            featureById.set(data.id, feature);
        }
        flagSource.addFeature(feature);
        window.dispatchEvent(new CustomEvent('marks:changed', {
            detail: { action: 'added', item: data }
        }));
    });

    return {
        flagSource,
        flagLayer,
        getFeatureById: (id) => featureById.get(id),
        highlightFeatureById: (id) => highlightFeature(featureById.get(id))
    };
}
