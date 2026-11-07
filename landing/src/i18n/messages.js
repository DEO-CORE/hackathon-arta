import common from "./common.js";
import home from "./home.js";
import forms from "./forms.js";
import content from "./content.js";
export const messages = Object.fromEntries(
  [...common, ...home, ...forms, ...content].map(([source, en, ky]) => [
    source,
    { en, ky },
  ]),
);
