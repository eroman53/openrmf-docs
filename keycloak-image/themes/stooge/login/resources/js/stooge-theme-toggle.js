/*
 * STOOGE appearance switch for the Keycloak login pages.
 *
 * The base template already applies the dark class from the OS setting when
 * darkMode=true. This adds an explicit choice on top: pick light or dark and
 * it sticks in this browser; clear it and the OS setting takes over again.
 *
 * Loaded through the theme's `scripts=` property, so no FreeMarker template
 * has to be copied into this theme.
 */
(function () {
    "use strict";

    var DARK_CLASS = "pf-v5-theme-dark";
    var STORAGE_KEY = "stooge-color-scheme"; // "dark" | "light" | absent = follow the OS
    var media = window.matchMedia("(prefers-color-scheme: dark)");

    // private-mode browsers throw on storage access; the toggle still works
    // for the current page in that case, it just will not be remembered.
    function readChoice() {
        try {
            return window.localStorage.getItem(STORAGE_KEY);
        } catch (e) {
            return null;
        }
    }

    function writeChoice(value) {
        try {
            if (value) {
                window.localStorage.setItem(STORAGE_KEY, value);
            } else {
                window.localStorage.removeItem(STORAGE_KEY);
            }
        } catch (e) {
            /* not fatal -- the choice just does not persist */
        }
    }

    function wantsDark() {
        var choice = readChoice();
        return choice ? choice === "dark" : media.matches;
    }

    function apply() {
        var dark = wantsDark();
        document.documentElement.classList.toggle(DARK_CLASS, dark);

        // The base template emits <meta name="color-scheme" content="light dark">,
        // so the browser paints its own canvas and default text from the OS
        // setting no matter what class is on the root. Without this line an
        // explicit light choice on a dark OS leaves a dark page behind a light
        // card, and the wordmark and labels disappear.
        document.documentElement.style.colorScheme = dark ? "dark" : "light";

        var button = document.getElementById("stooge-theme-toggle");
        if (button) {
            button.textContent = dark ? "\u2600 Light" : "\u263E Dark";
            button.setAttribute("aria-pressed", String(dark));
            button.setAttribute("title", dark
                ? "Switch to light appearance"
                : "Switch to dark appearance");
            button.setAttribute("aria-label", button.getAttribute("title"));
        }
    }

    // The base template also listens for this and sets the class from the OS
    // alone. Defer so an explicit choice is re-asserted after it runs.
    media.addEventListener("change", function () {
        window.setTimeout(apply, 0);
    });

    // run once in <head> so there is no flash of the wrong appearance
    apply();

    document.addEventListener("DOMContentLoaded", function () {
        var button = document.createElement("button");
        button.id = "stooge-theme-toggle";
        button.type = "button";
        button.addEventListener("click", function () {
            writeChoice(wantsDark() ? "light" : "dark");
            apply();
        });
        document.body.appendChild(button);
        apply(); // re-assert: the base module script runs before this point
    });
})();
