// Основная логика приложения карты
// Функция создания и инициализации приложения Vue

function initMapApp() {
    const { createApp, onMounted, ref } = Vue;

    return {
        setup() {
            const mapRef = ref(null);
            const sidebarOpen = ref(false);
            const showProfile = ref(false);
            const showMarks = ref(false);
            const searchQuery = ref('');
            const activeFilter = ref('all');

            // Тестовые данные меток
            const allMarks = ref([
                { title: 'Кофейня Прима', category: 'Кафе', distance: 120, rating: 4.8 },
                { title: 'Скамейка у парка', category: 'Скамейки', distance: 250, rating: 4.5 },
                { title: 'Арт-стена', category: 'Арт', distance: 380, rating: 4.9 },
                { title: 'Маленькое кафе', category: 'Кафе', distance: 450, rating: 4.6 },
                { title: 'Деревянная скамейка', category: 'Скамейки', distance: 520, rating: 4.3 },
                { title: 'Граффити лев', category: 'Арт', distance: 680, rating: 5.0 }
            ]);

            const filteredMarks = ref([]);

            const updateFilteredMarks = () => {
                let marks = allMarks.value;

                // Фильтр по категории
                if (activeFilter.value !== 'all') {
                    const filterMap = {
                        'cafe': 'Кафе',
                        'bench': 'Скамейки',
                        'art': 'Арт'
                    };
                    marks = marks.filter(m => m.category === filterMap[activeFilter.value]);
                }

                // Поиск
                if (searchQuery.value) {
                    marks = marks.filter(m =>
                        m.title.toLowerCase().includes(searchQuery.value.toLowerCase())
                    );
                }

                filteredMarks.value = marks;
            };

            const panelCtx = {
                get sidebarOpen() { return sidebarOpen.value; },
                set sidebarOpen(v) { sidebarOpen.value = v; },

                get showProfile() { return showProfile.value; },
                set showProfile(v) { showProfile.value = v; },

                get showMarks() { return showMarks.value; },
                set showMarks(v) { showMarks.value = v; },

                updateFilteredMarks
            };

            const handleListMarks = sidePanelHandlers.handleListMarks.bind(panelCtx);
            const handleAddMark = sidePanelHandlers.handleAddMark.bind(panelCtx);
            const handleProfile = sidePanelHandlers.handleProfile.bind(panelCtx);
            const handleBackToMenu = sidePanelHandlers.handleBackToMenu.bind(panelCtx);
            const handleSelectMark = sidePanelHandlers.handleSelectMark.bind(panelCtx);
            const handleRating = sidePanelHandlers.handleRating.bind(panelCtx);

            onMounted(() => {
                const map = new ol.Map({
                    target: 'map',
                    layers: [
                        new ol.layer.Tile({
                            source: new ol.source.OSM() // OpenStreetMap
                        })
                    ],
                    view: new ol.View({
                        center: ol.proj.fromLonLat([37.6188, 55.7517]), // ?????? (??????)
                        zoom: 10
                    })
                });

                initAddMark(map);

                mapRef.value = map;
                updateFilteredMarks();
            });



            // ???????????????????? ?????? state ?? ????????????
            return {
                mapRef,
                sidebarOpen,
                showProfile,
                showMarks,
                searchQuery,
                activeFilter,
                filteredMarks,
                updateFilteredMarks,
                handleListMarks,
                handleAddMark,
                handleProfile,
                handleBackToMenu,
                handleSelectMark,
                handleRating
            };
        }
    };
}

