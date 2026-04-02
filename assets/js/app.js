let data = {};
let productsFlat = [];


function closeSidebarMobile() {
    if (window.innerWidth < 992) {
        document.querySelector(".sidebar").classList.remove("active");
        document.getElementById("overlay").classList.remove("active");
    }
}

function toggleSidebar() {
    const sidebar = document.querySelector(".sidebar");
    const overlay = document.getElementById("overlay");

    sidebar.classList.toggle("active");
    overlay.classList.toggle("active");
}

function setActive(el) {
    document.querySelectorAll('.menu-item, .brand-item')
        .forEach(i => i.classList.remove('active'));

    el.classList.add('active');
}

// =======================
// SEARCH
// =======================

document.addEventListener("input", function (e) {
    if (e.target.id === "searchInput") {

        const keyword = e.target.value.toLowerCase();
        const container = document.getElementById("productList");

        hideAll();
        container.style.display = "flex";
        container.innerHTML = "";

        const filtered = productsFlat.filter(p =>
            (p.part_numbers || []).some(row =>
                row[0]?.toLowerCase().includes(keyword)
            )
        );

        filtered.forEach(p => {
            container.innerHTML += `
            <div class="col-md-4 mb-4">
                <div class="card p-3" onclick="showDetail('${p.brand}','${key}')">
                    <h6>${p.name}</h6>
                    <p>${p.short_description || ''}</p>
                </div>
            </div>
            `;
        });

        if (filtered.length === 0) {
            container.innerHTML = "<p>Không tìm thấy</p>";
        }
    }
});

document.addEventListener("DOMContentLoaded", function () {
    const links = document.querySelectorAll(".brand-item");
    const currentPath = window.location.pathname;
    console.log("currentPath", currentPath)

    links.forEach(link => {
        const linkPath = link.getAttribute("href");
        console.log("linkPath", linkPath)

        if (
            (linkPath === "/" && currentPath === "/") ||
            (linkPath !== "/" && currentPath.startsWith(linkPath))
        ) {
            link.classList.add("active");
        }
    });
});

$(".product-carousel").owlCarousel({
    loop: true,
    margin: 15,
    nav: false,
    dots: false,

    autoplay: true,
    autoplayTimeout: 2500,
    smartSpeed: 1000,
    autoplayHoverPause: true,

    responsive: {
        0: { items: 1 },
        576: { items: 1 },
        768: { items: 1 },
        992: { items: 1 }
    }
});