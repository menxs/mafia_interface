// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import "../css/app.scss"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import deps with the dep name or local files with a relative path, for example:
//
//     import {Socket} from "phoenix"
//     import socket from "./socket"
//
import "phoenix_html"
import {Socket} from "phoenix"
import NProgress from "nprogress"
import {LiveSocket} from "phoenix_live_view"

let Hooks = {}
Hooks.InviteButton = {
  mounted() {
    this.el.addEventListener("click", e => {
      var temp = document.createElement("input");
      temp.value = window.location.href;
      document.body.appendChild(temp);
      temp.select();
      temp.setSelectionRange(0, 99999);
      document.execCommand("copy");
      temp.remove();
      var invBtn = document.getElementById("invite-button")
      this.el.innerHTML = "Copied";
      setTimeout(e => {this.el.innerHTML = "Invite";}, 1500);
    })
  }
}
Hooks.TableTab = {
  mounted() {
    this.el.addEventListener("click", e => {
      document.querySelector("th.selected-tab").classList.remove("selected-tab");
      this.el.classList.add("selected-tab");
      
      document.querySelector("[id^=table-]:not([hidden])").setAttribute("hidden", "");
      document.getElementById(this.el.id.replace("tab-", "table-")).removeAttribute("hidden");
    })
  }
}
Hooks.TableContent = {
  updated() {
    var tab = document.getElementById(this.el.id.replace("table-", "tab-"));
    if (tab.classList.contains("selected-tab")) {
      this.el.removeAttribute("hidden");
    } else {
      this.el.setAttribute("hidden", "");
    }
  }
}
Hooks.RefreshAlert = {
  mounted() {
    window.onbeforeunload = function(event)
      {
        return confirm("Confirm refresh");
      };
  },
  destroyed() {
    window.onbeforeunload = function(event){};
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: Hooks})

// Show progress bar on live navigation and form submits
window.addEventListener("phx:page-loading-start", info => NProgress.start())
window.addEventListener("phx:page-loading-stop", info => NProgress.done())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket