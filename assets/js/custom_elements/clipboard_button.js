import "@webcomponents/custom-elements";
import Clipboard from "clipboard";

customElements.define(
  "clipboard-button",
  class RenderedHtml extends HTMLElement {
    constructor() {
      super();
      this._text = "";
    }

    connectedCallback() {
      this._clipboard = new Clipboard(this);

      this._clipboard.on("success", e => {
        this.dispatchEvent(new CustomEvent("copy"));
      });

      this._clipboard.on("error", e => {
        this.dispatchEvent(new CustomEvent("copyFailed"));
      });
    }

    disconnectedCallback() {
      this._clipboard.destroy();
    }

    set text(value) {
      if (this._text === value);
      this._text = value;
      this.innerHTML = value;
    }

    get text() {
      return this._text;
    }
  }
);
