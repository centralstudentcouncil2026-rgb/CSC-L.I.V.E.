(() => {
    const dashboardBackgroundImages = [
        "./dashboard-backgrounds/56435184_2377398058971412_6905733492668104704_n.jpg",
        "./dashboard-backgrounds/469984691_918281827068965_7471383534469226798_n.jpg",
        "./dashboard-backgrounds/472760250_9329332677111214_8161660048911603548_n.jpg",
        "./dashboard-backgrounds/671018030_1284495603780917_8907957753481931746_n.jpg",
        // Add more images here, for example:
        // "dashboard-backgrounds/csc-cup-1.jpg",
        // "dashboard-backgrounds/csc-cup-2.png",
        // "dashboard-backgrounds/csc-cup-3.webp"
    ];

    let backgroundTimer = null;

    function applyDashboardBackgrounds(images) {
        const safeImages = Array.isArray(images) ? images.filter(Boolean) : [];
        window.clearInterval(backgroundTimer);
        document.body.classList.remove("dashboard-bg-show-b");

        if (safeImages.length === 0) {
            document.documentElement.style.removeProperty("--dashboard-photo-url");
            document.documentElement.style.removeProperty("--dashboard-photo-url-a");
            document.documentElement.style.removeProperty("--dashboard-photo-url-b");
            document.documentElement.style.removeProperty("--dashboard-photo-size");
            return;
        }

        safeImages.forEach((src) => {
            const image = new Image();
            image.src = src;
        });

        let currentIndex = 0;
        let visibleLayer = "a";
        document.documentElement.style.setProperty("--dashboard-photo-size", "cover");
        document.documentElement.style.setProperty("--dashboard-photo-url-a", `url("${safeImages[currentIndex]}")`);
        document.documentElement.style.setProperty("--dashboard-photo-url-b", `url("${safeImages[currentIndex]}")`);

        if (safeImages.length > 1) {
            backgroundTimer = window.setInterval(() => {
                currentIndex = (currentIndex + 1) % safeImages.length;
                const nextUrl = `url("${safeImages[currentIndex]}")`;

                if (visibleLayer === "a") {
                    document.documentElement.style.setProperty("--dashboard-photo-url-b", nextUrl);
                    window.requestAnimationFrame(() => document.body.classList.add("dashboard-bg-show-b"));
                    visibleLayer = "b";
                } else {
                    document.documentElement.style.setProperty("--dashboard-photo-url-a", nextUrl);
                    window.requestAnimationFrame(() => document.body.classList.remove("dashboard-bg-show-b"));
                    visibleLayer = "a";
                }
            }, 8500);
        }
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", () => applyDashboardBackgrounds(dashboardBackgroundImages));
    } else {
        applyDashboardBackgrounds(dashboardBackgroundImages);
    }
})();
