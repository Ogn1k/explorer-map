// Основная логика приложения карты
// Функция создания и инициализации приложения Vue

function initMapApp() {
    const { createApp, onMounted, ref, computed } = Vue;

    return {
        setup() {
            const mapRef = ref(null);
            const sidebarOpen = ref(false);
            const showProfile = ref(false);
            const showMarks = ref(false);
            const showAddMark = ref(false);
            const searchQuery = ref('');
            const activeFilter = ref('all');
            const newMark = ref({
                title: '',
                category: '',
                description: ''
            });

            // Тестовые данные меток
            const allMarks = ref([]);

            const filteredMarks = computed(() => {
                let marks = allMarks.value;

                // ?????? ?? ?????????
                if (activeFilter.value !== 'all') {
                    const filterMap = {
                        'cafe': '????',
                        'bench': '????????',
                        'art': '???'
                    };
                    marks = marks.filter(m => m.category === filterMap[activeFilter.value]);
                }

                // ?????
                if (searchQuery.value) {
                    marks = marks.filter(m =>
                        m.title.toLowerCase().includes(searchQuery.value.toLowerCase())
                    );
                }

                return marks;
            });

            const loadMarksFromDb = async () => {
                const res = await fetch('/api/marks/');
                if (!res.ok) {
                    console.error('Failed to load marks list', await res.text());
                    return;
                }

                const data = await res.json();
                if (!data || !Array.isArray(data.items)) {
                    return;
                }

                allMarks.value = data.items.map((item) => ({
                    id: item.id,
                    title: item.name,
                    category: '??? ?????????',
                    distance: '',
                    rating: '',
                    description: item.description,
                    latitude: item.latitude,
                    longitude: item.longitude,
                    created_at: item.created_at
                }));
            };

            const upsertMarkInList = (item) => {
                if (!item || !item.id) {
                    return;
                }

                const normalized = {
                    id: item.id,
                    title: item.name,
                    category: 'Без категории',
                    distance: '',
                    rating: '',
                    description: item.description,
                    latitude: item.latitude,
                    longitude: item.longitude,
                    created_at: item.created_at
                };

                const index = allMarks.value.findIndex((m) => m.id === item.id);
                if (index === -1) {
                    allMarks.value.push(normalized);
                } else {
                    allMarks.value.splice(index, 1, normalized);
                }
            };

            const removeMarkFromList = (id) => {
                if (!id) {
                    return;
                }
                allMarks.value = allMarks.value.filter((m) => m.id !== id);
            };

            const panelCtx = {
                get sidebarOpen() { return sidebarOpen.value; },
                set sidebarOpen(v) { sidebarOpen.value = v; },

                get showProfile() { return showProfile.value; },
                set showProfile(v) { showProfile.value = v; },

                get showMarks() { return showMarks.value; },
                set showMarks(v) { showMarks.value = v; },

                get showAddMark() { return showAddMark.value; },
                set showAddMark(v) { showAddMark.value = v; },

                updateFilteredMarks: () => {}
            };

            const handleListMarks = sidePanelHandlers.handleListMarks.bind(panelCtx);
            const handleAddMark = sidePanelHandlers.handleAddMark.bind(panelCtx);
            const handleProfile = sidePanelHandlers.handleProfile.bind(panelCtx);
            const handleBackToMenu = sidePanelHandlers.handleBackToMenu.bind(panelCtx);
            const addMarkApiRef = ref(null);

            const handleSelectMark = (mark) => {
                if (!mark || !mapRef.value) {
                    return;
                }

                const map = mapRef.value;
                const center = ol.proj.fromLonLat([mark.longitude, mark.latitude]);
                const view = map.getView();
                const targetZoom = Math.max(view.getZoom() || 0, 15);

                view.animate({ center, zoom: targetZoom, duration: 500 });

                if (addMarkApiRef.value && mark.id) {
                    addMarkApiRef.value.highlightFeatureById(mark.id);
                }
            };
            const handleRating = sidePanelHandlers.handleRating.bind(panelCtx);

            onMounted(() => {
                window.addEventListener('marks:changed', (event) => {
                    const detail = event && event.detail ? event.detail : null;
                    if (!detail || !detail.action) {
                        loadMarksFromDb();
                        return;
                    }

                    if (detail.action === 'added') {
                        upsertMarkInList(detail.item);
                                                return;
                    }

                    if (detail.action === 'deleted') {
                        removeMarkFromList(detail.id);
                                                return;
                    }

                    loadMarksFromDb();
                });
                const map = new ol.Map({
                    target: 'map',
                    layers: [
                        new ol.layer.Tile({
                            source: new ol.source.OSM() // OpenStreetMap
                        })
                    ],
                    view: new ol.View({
                        center: ol.proj.fromLonLat([37.6188, 55.7517]), // Москва (пример)
                        zoom: 10
                    })
                });

                addMarkApiRef.value = initAddMark(map);

                mapRef.value = map;
                loadMarksFromDb();
            });

            // Обработчик сохранения новой метки
            const handleSaveMark = () => {
                if (!newMark.value.title || !newMark.value.category) {
                    alert('Пожалуйста, заполните все обязательные поля');
                    return;
                }

                console.warn('Сохранение метки через форму не привязано к базе данных.');

                // Сбрасываем форму
                newMark.value = {
                    title: '',
                    category: '',
                    description: ''
                };

                // Закрываем форму добавления
                showAddMark.value = false;
                loadMarksFromDb();
            };



            // Возвращаем все state и методы
            return {
                mapRef,
                sidebarOpen,
                showProfile,
                showMarks,
                showAddMark,
                searchQuery,
                activeFilter,
                filteredMarks,
                newMark,
                handleListMarks,
                handleAddMark,
                handleProfile,
                handleBackToMenu,
                handleSelectMark,
                handleRating,
                handleSaveMark
            };
        }
    };
}

