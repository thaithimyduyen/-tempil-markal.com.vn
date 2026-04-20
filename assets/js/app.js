/* app.js — Fast Group Engineering | markal.com.vn */

(function () {
    'use strict';

    /* -------------------------------------------
       Mobile Menu Toggle
       ------------------------------------------- */
    const hamburger = document.getElementById('hamburger');
    const sidebar   = document.getElementById('sidebar');
    const overlay   = document.getElementById('sidebarOverlay');

    if (hamburger && sidebar && overlay) {
        const navLinks = sidebar.querySelectorAll('.sidebar__nav a');

        function openMenu() {
            sidebar.classList.add('is-open');
            overlay.style.display = 'block';
            hamburger.classList.add('is-active');
            hamburger.setAttribute('aria-expanded', 'true');
            requestAnimationFrame(function () {
                overlay.classList.add('is-visible');
            });
        }

        function closeMenu() {
            sidebar.classList.remove('is-open');
            overlay.classList.remove('is-visible');
            hamburger.classList.remove('is-active');
            hamburger.setAttribute('aria-expanded', 'false');
            setTimeout(function () {
                overlay.style.display = 'none';
            }, 300);
        }

        hamburger.addEventListener('click', function () {
            sidebar.classList.contains('is-open') ? closeMenu() : openMenu();
        });

        overlay.addEventListener('click', closeMenu);

        navLinks.forEach(function (link) {
            link.addEventListener('click', function () {
                if (window.innerWidth <= 1024) closeMenu();
            });
        });

        /* Active nav link based on current path */
        const currentPath = window.location.pathname;
        navLinks.forEach(function (link) {
            const linkPath = new URL(link.href, location.origin).pathname;
            if (
                (linkPath === '/' && currentPath === '/') ||
                (linkPath !== '/' && currentPath.startsWith(linkPath))
            ) {
                link.classList.add('active');
            }
        });

        /* Active nav highlight on scroll (chỉ cho trang có anchor sections) */
        const sections = document.querySelectorAll('section[id]');
        if (sections.length) {
            function updateActiveNav() {
                const scrollY = window.scrollY + 120;
                sections.forEach(function (section) {
                    const id = section.getAttribute('id');
                    const link = sidebar.querySelector('.sidebar__nav a[href="#' + id + '"]');
                    if (!link) return;
                    const inView = scrollY >= section.offsetTop &&
                                   scrollY < section.offsetTop + section.offsetHeight;
                    link.classList.toggle('active', inView);
                });
            }
            window.addEventListener('scroll', updateActiveNav, { passive: true });
        }
    }

    /* -------------------------------------------
       Scroll-Triggered Reveal Animations
       ------------------------------------------- */
    const revealElements = document.querySelectorAll('.reveal');

    if (revealElements.length) {
        if ('IntersectionObserver' in window) {
            const revealObserver = new IntersectionObserver(function (entries) {
                entries.forEach(function (entry) {
                    if (entry.isIntersecting) {
                        entry.target.classList.add('is-visible');
                        revealObserver.unobserve(entry.target);
                    }
                });
            }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });

            revealElements.forEach(function (el) {
                revealObserver.observe(el);
            });
        } else {
            revealElements.forEach(function (el) {
                el.classList.add('is-visible');
            });
        }
    }

    /* -------------------------------------------
       Seasonal Tabs (chỉ chạy nếu có tabs trên trang)
       ------------------------------------------- */
    const tabs   = document.querySelectorAll('.seasonal-tab');
    const panels = document.querySelectorAll('.seasonal-panel');

    if (tabs.length && panels.length) {
        let currentIndex = 0;
        let autoTimer    = null;
        const tabContainer = tabs[0].closest('.seasonal-tabs') || document.body;

        function activateTab(index) {
            currentIndex = index;
            tabs.forEach(function (tab, i) {
                tab.classList.toggle('is-active', i === index);
                tab.setAttribute('aria-selected', i === index);
            });
            panels.forEach(function (panel, i) {
                panel.classList.toggle('is-active', i === index);
            });
        }

        function startAuto() {
            autoTimer = setInterval(function () {
                activateTab((currentIndex + 1) % tabs.length);
            }, 4000);
        }

        function stopAuto() {
            clearInterval(autoTimer);
        }

        /* Click để chọn tab */
        tabs.forEach(function (tab, index) {
            tab.addEventListener('click', function () {
                stopAuto();
                activateTab(index);
                startAuto();
            });
        });

        /* Dừng tự động khi hover */
        tabContainer.addEventListener('mouseenter', stopAuto);
        tabContainer.addEventListener('mouseleave', startAuto);

        startAuto();
    }

    /* -------------------------------------------
       Smooth Scroll cho anchor links
       ------------------------------------------- */
    document.querySelectorAll('a[href^="#"]').forEach(function (anchor) {
        anchor.addEventListener('click', function (e) {
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                e.preventDefault();
                target.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        });
    });

})();
