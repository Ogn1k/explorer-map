// Обработчики событий для боковой панели
// Функции для управления состоянием меню, профиля и меток

const sidePanelHandlers = {
    handleListMarks() {
        console.log('Список меток clicked');
        this.showMarks = true;
        this.showProfile = false;
    },

    handleAddMark() {
        console.log('Добавить метку clicked');
        this.showAddMark = true;
        this.showProfile = false;
        this.showMarks = false;
    },

    handleProfile() {
        console.log('Профиль clicked');
        this.showProfile = true;
        this.showMarks = false;
    },

    handleBackToMenu() {
        console.log('Back to menu clicked');
        this.showProfile = false;
        this.showMarks = false;
        this.showAddMark = false;
    },

    handleSelectMark(mark) {
        console.log('Mark selected:', mark);
        // Добавьте логику выбора метки на карте
    },

    handleRating() {
        console.log('Рейтинг clicked');
        this.sidebarOpen = false;
        this.showProfile = false;
        this.showMarks = false;
        // Add your logic here
    }
};

