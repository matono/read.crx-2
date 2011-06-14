app.view = {}

app.view.module = {}
app.view.module.searchbox_thread_title = ($view, target_col) ->
  $view.find(".searchbox_thread_title")
    .bind "input", ->
      $view.find("table")
        .table_search("search", {query: this.value, target_col})
    .bind "keyup", (e) ->
      if e.which is 27 #Esc
        this.value = ""
        $view.find("table").table_search("clear")

app.view.module.bookmark_button = ($view) ->
  url = $view.attr("data-url")
  $button = $view.find(".button_bookmark")
  if ///^http://\w///.test(url)
    if app.bookmark.get(url)
      $button.addClass("bookmarked")
    else
      $button.removeClass("bookmarked")

    on_update = (message) ->
      if message.bookmark.url is url
        if message.type is "added"
          $button.addClass("bookmarked")
        else if message.type is "removed"
          $button.removeClass("bookmarked")

    app.message.add_listener("bookmark_updated", on_update)

    $view.bind "tab_removed", ->
      app.message.remove_listener("bookmark_updated", on_update)

    $button.bind "click", ->
      if app.bookmark.get(url)
        app.bookmark.remove(url)
      else
        app.bookmark.add(url, $view.attr("data-title") or url)
  else
    $button.remove()

app.view.module.link_button = ($view) ->
  url = $view.attr("data-url")
  $button = $view.find(".button_link")
  if ///^http://\w///.test(url)
    $("<a>", href: url, target: "_blank")
      .appendTo($button)
  else
    $button.remove()

app.view.module.reload_button = ($view) ->
  $view.find(".button_reload").bind "click", ->
    $view.trigger("request_reload")

app.view.module.board_contextmenu = ($view) ->
  $view
    #コンテキストメニュー 表示
    .delegate "tbody tr", "click, contextmenu", (e) ->
      if e.type is "contextmenu"
        e.preventDefault()

      app.defer =>
        $menu = $("#template > .view_module_board_contextmenu")
          .clone()
            .data("contextmenu_source", this)
            .appendTo($view)

        url = this.getAttribute("data-href")
        if app.bookmark.get(url)
          $menu.find(".add_bookmark").remove()
        else
          $menu.find(".del_bookmark").remove()

        $.contextmenu($menu, e.clientX, e.clientY)

    #コンテキストメニュー 項目クリック
    .delegate ".view_module_board_contextmenu > *", "click", ->
      $this = $(this)
      $tr = $($this.parent().data("contextmenu_source"))

      url = $tr.attr("data-href")
      if $view.is(".view_bookmark")
        title = $tr.find("td:nth-child(1)").text()
      else if $view.is(".view_board")
        title = $tr.find("td:nth-child(2)").text()
      else
        app.log("error", "app.view.module.board_contextmenu: 想定外の状況で呼び出されました")

      if $this.hasClass("add_bookmark")
        app.bookmark.add(url, title)
      else if $this.hasClass("del_bookmark")
        app.bookmark.remove(url)

      $this.parent().remove()

app.view.sidemenu = {}
app.view.sidemenu.open = ->
  $view = $("#template > .view_bbsmenu").clone()

  app.bbsmenu.get (res) ->
    if "data" of res
      frag = document.createDocumentFragment()
      for category in res.data
        h3 = document.createElement("h3")
        h3.textContent = category.title
        frag.appendChild(h3)

        ul = document.createElement("ul")
        for board in category.board
          li = document.createElement("li")
          a = document.createElement("a")
          a.className = "open_in_rcrx"
          a.textContent = board.title
          a.href = board.url
          li.appendChild(a)
          ul.appendChild(li)
        frag.appendChild(ul)

    bookmark_container = document.createElement("div")
    bookmark_container.className = "bookmark"
    for bookmark in app.bookmark.get_all()
      if bookmark.type is "board"
        li = document.createElement("li")
        a = document.createElement("a")
        a.className = "open_in_rcrx"
        a.href = bookmark.url
        a.textContent = bookmark.title
        li.appendChild(a)
        bookmark_container.appendChild(li)

    $view
      .find("ul")
        .append(bookmark_container)
      .end()
      .append(frag)
      .accordion()

  $view

app.view.setup_resizer = ->
  $tab_a = $("#tab_a")
  tab_a = $tab_a[0]
  offset = $tab_a.outerHeight() - $tab_a.height()

  min_height = 50
  max_height = document.body.offsetHeight - 50

  tmp = app.config.get("tab_a_height")
  if tmp
    tab_a.style["height"] =
      Math.max(Math.min(tmp - offset, max_height), min_height) + "px"

  $("#tab_resizer")
    .bind "mousedown", (e) ->
      e.preventDefault()

      min_height = 50
      max_height = document.body.offsetHeight - 50

      $("<div>", {css: {
        position: "absolute"
        left: 0
        top: 0
        width: "100%"
        height: "100%"
        "z-index": 999
        cursor: "row-resize"
      }})
        .bind "mousemove", (e) ->
          tab_a.style["height"] =
            Math.max(Math.min(e.pageY - offset, max_height), min_height) + "px"
        .bind "mouseup", ->
          $(this).remove()
          app.config.set("tab_a_height", parseInt(tab_a.style["height"], 10))
        .appendTo("body")

app.view.history = {}

app.view.history.open = ->
  $view = $("#template > .view_history").clone()
  $("#tab_a").tab("add", element: $view[0], title: "閲覧履歴")

  app.history.get(undefined, 500)
    .done (data) ->
      frag = document.createDocumentFragment()
      for val in data
        tr = document.createElement("tr")
        tr.setAttribute("data-href", val.url)
        tr.className = "open_in_rcrx"

        td = document.createElement("td")
        td.textContent = val.title
        tr.appendChild(td)

        td = document.createElement("td")
        td.textContent = app.util.date_to_string(new Date(val.date))
        tr.appendChild(td)
        frag.appendChild(tr)
      $view.find("tbody").append(frag)

app.view.bookmark_source_selector = {}

app.view.bookmark_source_selector.open = ->
  if $(".view_bookmark_source_selector:visible").length isnt 0
    app.log("debug", "app.view.bookmark_source_selector.open: " +
      "既にブックマークフォルダ選択ダイアログが開かれています")
    return

  $view = $("#template > .view_bookmark_source_selector")
    .clone()
      .delegate ".node", "click", ->
        $(this)
          .closest(".view_bookmark_source_selector")
            .find(".selected")
              .removeClass("selected")
            .end()
            .find(".submit")
              .removeAttr("disabled")
            .end()
          .end()
          .addClass("selected")
      .find(".submit")
        .bind "click", ->
          bookmark_id = (
            $(this)
              .closest(".view_bookmark_source_selector")
                .find(".node.selected")
                  .attr("data-bookmark_id")
          )
          app.bookmark.change_source(bookmark_id)
          $(this)
            .closest(".view_bookmark_source_selector")
              .fadeOut "fast", ->
                $(this).remove()
      .end()
      .appendTo(document.body)

  fn = (array_of_tree, ul) ->
    for tree in array_of_tree
      if "children" of tree
        li = document.createElement("li")
        span = document.createElement("span")
        span.className = "node"
        span.textContent = tree.title
        span.setAttribute("data-bookmark_id", tree.id)
        li.appendChild(span)
        ul.appendChild(li)

        cul = document.createElement("ul")
        li.appendChild(cul)

        fn(tree.children, cul)
    null

  chrome.bookmarks.getTree (array_of_tree) ->
    fn(array_of_tree[0].children, $view.find(".node_list > ul")[0])

