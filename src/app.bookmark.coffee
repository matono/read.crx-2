app.bookmark = {}

(->
  source_id = app.config.get("bookmark_id")
  bookmark_data = []
  bookmark_data_index_url = {}
  bookmark_data_index_id = {}
  index_url_id = {}
  watcher_wakeflg = true

  hoge_bookmark = (bookmark_node) ->
    guess_res = app.url.guess_type(bookmark_node.url)
    if guess_res.type is "board" or guess_res.type is "thread"
      url = app.url.fix(bookmark_node.url)
      tmp_bookmark =
        type: guess_res.type
        bbs_type: guess_res.bbs_type
        url: url
        title: bookmark_node.title
        res_count: null

      tmp = app.url.parse_hashquery(bookmark_node.url)

      if /^\d+$/.test(tmp.res_count)
        tmp_bookmark.res_count = +tmp.res_count

      if (
        /^\d+$/.test(tmp.received) and
        /^\d+$/.test(tmp.read) and
        /^\d+$/.test(tmp.last)
      )
        tmp_bookmark.read_state =
          url: url
          received: +tmp.received
          read: +tmp.read
          last: +tmp.last

      bookmark_data.push(tmp_bookmark)
      bookmark_data_index_url[url] = bookmark_data.length - 1
      bookmark_data_index_id[bookmark_node.id] = bookmark_data.length - 1
      index_url_id[url] = bookmark_node.id

  update_all = ->
    try
      chrome.bookmarks.getChildren source_id, (array_of_tree) ->
        bookmark_data = []
        bookmark_data_index_url = {}
        bookmark_data_index_id = {}
        index_url_id = {}
        for tree in array_of_tree
          if "url" of tree
            hoge_bookmark(tree)
        send_update_message()
    catch e
      $(-> app.view.bookmark_source_selector.open())

  send_update_message = ->
    app.message.send("bookmark_updated", null)

  chrome.bookmarks.onImportBegan.addListener ->
    watcher_wakeflg = false

  chrome.bookmarks.onImportEnded.addListener ->
    watcher_wakeflg = true
    update_all()

  chrome.bookmarks.onCreated.addListener (id, node) ->
    if watcher_wakeflg and node.parentId is source_id and "url" of node
      hoge_bookmark(node)
      send_update_message()

  chrome.bookmarks.onRemoved.addListener (id, e) ->
    if watcher_wakeflg and id of bookmark_data_index_id
      update_all()

  chrome.bookmarks.onChanged.addListener (id, e) ->
    if watcher_wakeflg and id of bookmark_data_index_id
      update_all()

  chrome.bookmarks.onMoved.addListener (id, e) ->
    if watcher_wakeflg
      if e.parentId is source_id or e.oldParentId is source_id
        update_all()

  update_all()

  # ##app.bookmark.get
  # 与えられたURLがブックマークされていた場合はbookmarkオブジェクトを  
  # そうでなかった場合はnullを返す
  app.bookmark.get = (url) ->
    if url of bookmark_data_index_url
      app.deep_copy(bookmark_data[bookmark_data_index_url[url]])
    else
      null

  # ##app.bookmark.get_all
  # 全てのbookmarkを格納した配列を返す
  app.bookmark.get_all = ->
    app.deep_copy(bookmark_data)

  app.bookmark.change_source = (new_source_id) ->
    if app.assert_arg("app.bookmark.change_source", ["string"], arguments)
      return

    app.config.set("bookmark_id", new_source_id)
    source_id = new_source_id
    update_all()

  app.bookmark.add = (url, title) ->
    if app.assert_arg("app.bookmark.add", ["string", "string"], arguments)
      return

    url = app.url.fix(url)
    unless url of bookmark_data_index_url
      chrome.bookmarks.create({parentId: source_id, url, title})
    else
      app.log("error", "app.bookmark.add: 既にブックマークされいてるURLをブックマークに追加しようとしています", arguments)

  app.bookmark.remove = (url) ->
    if app.assert_arg("app.bookmark.remove", ["string"], arguments)
      return

    id = index_url_id[app.url.fix(url)]
    if typeof id is "string"
      chrome.bookmarks.remove(id)
    else
      app.log("error", "app.bookmark.remove: ブックマークされていないURLをブックマークから削除しようとしています", arguments)

  app.bookmark.update_read_state = (read_state) ->
    url = read_state.url
    if bookmark = app.bookmark.get(url)
      if bookmark.read_state and
          bookmark.read_state.received is read_state.received and
          bookmark.read_state.read is read_state.read and
          bookmark.read_state.last is read_state.last
        return

      data =
        received: read_state.received
        read: read_state.read
        last: read_state.last

      if bookmark.res_count
        data.res_count = bookmark.res_count

      chrome.bookmarks.update(index_url_id[url],
        url: read_state.url + "#" + app.url.build_param(data))

  app.bookmark.update_res_count = (url, res_count) ->
    if bookmark = app.bookmark.get(url)
      if bookmark.res_count is res_count
        return

      data = {res_count}

      if bookmark.read_state
        data.received = bookmark.read_state.received
        data.read = bookmark.read_state.read
        data.last = bookmark.read_state.last

      chrome.bookmarks.update(index_url_id[url],
        url: url + "#" + app.url.build_param(data))
)()
