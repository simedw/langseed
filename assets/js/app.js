// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/langseed"
import topbar from "../vendor/topbar"
import * as d3 from "../vendor/d3.min.js"

// Text-to-speech hook for Chinese pronunciation
const Hooks = {
  WordGraph: {
    mounted() {
      const graphData = JSON.parse(this.el.dataset.graph)
      this.renderGraph(graphData)
      
      // Re-render on window resize
      this.resizeHandler = () => this.renderGraph(graphData)
      window.addEventListener('resize', this.resizeHandler)
    },
    
    destroyed() {
      if (this.resizeHandler) {
        window.removeEventListener('resize', this.resizeHandler)
      }
    },
    
    renderGraph(data) {
      // Clear existing content
      this.el.innerHTML = ''
      
      if (data.nodes.length === 0) {
        const emptyMessage = this.el.dataset.emptyMessage || 'No vocabulary data yet'
        this.el.innerHTML = `<div class="flex items-center justify-center h-full text-lg opacity-50">${emptyMessage}</div>`
        return
      }
      
      const width = this.el.clientWidth
      const height = this.el.clientHeight
      
      // Create SVG
      const svg = d3.select(this.el)
        .append("svg")
        .attr("width", width)
        .attr("height", height)
        .attr("viewBox", [0, 0, width, height])
      
      // Color scale based on understanding (red -> yellow -> green)
      const understandingColor = (level) => {
        if (level < 50) {
          const ratio = level / 50
          const r = 239
          const g = Math.round(68 + (171 - 68) * ratio)
          const b = Math.round(68 + (8 - 68) * ratio)
          return `rgb(${r}, ${g}, ${b})`
        } else {
          const ratio = (level - 50) / 50
          const r = Math.round(234 - (234 - 34) * ratio)
          const g = Math.round(179 + (197 - 179) * ratio)
          const b = Math.round(8 + (94 - 8) * ratio)
          return `rgb(${r}, ${g}, ${b})`
        }
      }
      
      // Create arrow marker for directed edges
      svg.append("defs").append("marker")
        .attr("id", "arrowhead")
        .attr("viewBox", "-0 -5 10 10")
        .attr("refX", 20)
        .attr("refY", 0)
        .attr("orient", "auto")
        .attr("markerWidth", 6)
        .attr("markerHeight", 6)
        .append("path")
        .attr("d", "M 0,-5 L 10,0 L 0,5")
        .attr("fill", "#888")
      
      // Create force simulation
      const simulation = d3.forceSimulation(data.nodes)
        .force("link", d3.forceLink(data.links).id(d => d.id).distance(80))
        .force("charge", d3.forceManyBody().strength(-200))
        .force("center", d3.forceCenter(width / 2, height / 2))
        .force("collision", d3.forceCollide().radius(30))
      
      // Create links (edges)
      const link = svg.append("g")
        .attr("class", "links")
        .selectAll("line")
        .data(data.links)
        .join("line")
        .attr("stroke", "#888")
        .attr("stroke-opacity", 0.4)
        .attr("stroke-width", 1.5)
        .attr("marker-end", "url(#arrowhead)")
      
      // Create node groups
      const node = svg.append("g")
        .attr("class", "nodes")
        .selectAll("g")
        .data(data.nodes)
        .join("g")
        .call(d3.drag()
          .on("start", (event, d) => {
            if (!event.active) simulation.alphaTarget(0.3).restart()
            d.fx = d.x
            d.fy = d.y
          })
          .on("drag", (event, d) => {
            d.fx = event.x
            d.fy = event.y
          })
          .on("end", (event, d) => {
            if (!event.active) simulation.alphaTarget(0)
            d.fx = null
            d.fy = null
          }))
      
      // Add circles to nodes
      const self = this
      node.append("circle")
        .attr("r", 15)
        .attr("fill", d => understandingColor(d.understanding))
        .attr("stroke", "#fff")
        .attr("stroke-width", 2)
        .style("cursor", "pointer")
        .on("click", (event, d) => {
          event.stopPropagation()
          self.pushEvent("select_word", { word: d.id })
        })
      
      // Add labels to nodes
      node.append("text")
        .text(d => d.id)
        .attr("text-anchor", "middle")
        .attr("dy", 5)
        .attr("font-size", "14px")
        .attr("font-weight", "bold")
        .attr("fill", "#fff")
        .style("pointer-events", "none")
        .style("text-shadow", "0 0 3px rgba(0,0,0,0.8)")
      
      // Add tooltip on hover
      node.append("title")
        .text(d => `${d.id}\n${d.pinyin}\n${d.meaning}\n理解: ${d.understanding}%`)
      
      // Update positions on simulation tick
      simulation.on("tick", () => {
        // Keep nodes within bounds
        data.nodes.forEach(d => {
          d.x = Math.max(20, Math.min(width - 20, d.x))
          d.y = Math.max(20, Math.min(height - 20, d.y))
        })
        
        link
          .attr("x1", d => d.source.x)
          .attr("y1", d => d.source.y)
          .attr("x2", d => d.target.x)
          .attr("y2", d => d.target.y)
        
        node.attr("transform", d => `translate(${d.x},${d.y})`)
      })
    }
  },
  
  /**
   * AudioPlayer hook - handles audio playback for speak buttons.
   * Events are filtered by component id to prevent multiple buttons playing at once.
   *
   * Events handled:
   * - speak-audio-play: Play audio from a URL (from SpeakButtonComponent)
   * - speak-browser-tts: Fall back to browser TTS (when TTS generation fails)
   */
  AudioPlayer: {
    mounted() {
      // Create a reusable audio element
      this.audio = new Audio()

      // Handle audio playback from LiveComponent (filtered by id)
      this.handleEvent("speak-audio-play", ({id, url}) => {
        // Only play if event is for this specific button
        if (id && id !== this.el.id) return
        
        this.el.dataset.audioUrl = url
        this.audio.src = url
        this.audio.play().catch(e => console.log('Audio play failed:', e))
      })

      // Handle browser TTS fallback from LiveComponent (filtered by id)
      this.handleEvent("speak-browser-tts", ({id, text, language}) => {
        // Only play if event is for this specific button
        if (id && id !== this.el.id) return
        
        this.playBrowserTTS(text, language)
      })
    },

    playBrowserTTS(text, language) {
      if (text && window.speechSynthesis) {
        window.speechSynthesis.cancel()

        const utterance = new SpeechSynthesisUtterance(text)
        utterance.lang = language === "zh" ? "zh-CN" : language
        utterance.rate = 0.8

        const voices = window.speechSynthesis.getVoices()
        const matchingVoice = voices.find(v => v.lang.startsWith(language))
        if (matchingVoice) {
          utterance.voice = matchingVoice
        }

        window.speechSynthesis.speak(utterance)
      }
    }
  },

  // Syncs audio autoplay preference from localStorage to server
  AudioAutoplaySync: {
    mounted() {
      this.sendPreference()
      
      // Listen for changes (when user toggles)
      window.addEventListener("phx:toggle-audio-autoplay", () => {
        // Small delay to let localStorage update first
        setTimeout(() => this.sendPreference(), 50)
      })
    },
    
    sendPreference() {
      const enabled = localStorage.getItem("phx:audio-autoplay") !== "false"
      this.pushEvent("audio_autoplay_changed", { enabled })
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

