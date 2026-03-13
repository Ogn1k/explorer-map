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

            onMounted(() => {
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

                mapRef.value = map;
                updateFilteredMarks();
            });

            // Обработчики событий боковой панели с правильным контекстом
            const handleListMarks = () => {
                console.log('Список меток clicked');
                showMarks.value = true;
                showProfile.value = false;
                updateFilteredMarks();
            };

            const handleAddMark = () => {
                console.log('Добавить метку clicked');
                sidebarOpen.value = false;
                showProfile.value = false;
                showMarks.value = false;
                // Add your logic here
            };

            const handleProfile = () => {
                console.log('Профиль clicked');
                showProfile.value = true;
                showMarks.value = false;
            };

            const handleBackToMenu = () => {
                console.log('Back to menu clicked');
                showProfile.value = false;
                showMarks.value = false;
            };

            const handleSelectMark = (mark) => {
                console.log('Mark selected:', mark);
                // Добавьте логику выбора метки на карте
            };

            const handleRating = () => {
                console.log('Рейтинг clicked');
                sidebarOpen.value = false;
                showProfile.value = false;
                showMarks.value = false;
                // Add your logic here
            };

            // Возвращаем все state и методы
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

