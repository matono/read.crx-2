describe "Content Security Policy", ->
  it "同一オリジンからのスクリプトのロードを許可する", ->
    #このテストが実行出来ている時点で、この項目は満たされている
    expect(true).toBe(true)
    return

  it "別オリジンからのスクリプトのロードを拒否する (google.com編)", ->
    onLoad = jasmine.createSpy("onLoad")
    onError = jasmine.createSpy("onError")

    script = document.createElement("script")
    script.src = "https://www.google.com/jsapi"
    script.addEventListener("load", onLoad)
    script.addEventListener("error", onError)
    document.body.appendChild(script)

    waitsFor -> onError.wasCalled

    runs ->
      expect(onLoad).not.toHaveBeenCalled()
      expect(onError).toHaveBeenCalled()
      document.body.removeChild(script)
      return
    return

  it "別オリジンからのスクリプトのロードを拒否する (Data URI編)", ->
    onLoad = jasmine.createSpy("onLoad")
    onError = jasmine.createSpy("onError")

    script = document.createElement("script")
    script.src = "data:text/plain,alert();"
    script.addEventListener("load", onLoad)
    script.addEventListener("error", onError)
    document.body.appendChild(script)

    waitsFor -> onError.wasCalled

    runs ->
      expect(onLoad).not.toHaveBeenCalled()
      expect(onError).toHaveBeenCalled()
      document.body.removeChild(script)
      return
    return

  it "インラインのスクリプト実行を拒否する (script要素編)", ->
    script = document.createElement("script")
    script.innerHTML = "window.___cspTest = true;"
    document.body.appendChild(script)

    expect(window.___cspTest).toBeUndefined()

    document.body.removeChild(script)
    return

  it "インラインのスクリプト実行を拒否する（a[href]編）", ->
    a = document.createElement("a")
    a.href = "javascript:void(window.cspTest = true);"
    document.body.appendChild(a)
    e = document.createEvent("MouseEvents")
    e.initMouseEvent("click")
    a.dispatchEvent(e)

    expect(window.___cspTest).toBeUndefined()

    document.body.removeChild(a)
    return

  it "インラインのスクリプト実行を拒否する （イベントハンドラ編）", ->
    span = document.createElement("span")
    span.setAttribute("onclick", "window.cspTest = true;")
    document.body.appendChild(span)
    e = document.createEvent("MouseEvents")
    e.initMouseEvent("click")
    span.dispatchEvent(e)

    expect(window.___cspTest).toBeUndefined()

    document.body.removeChild(span)
    return

  it "Data URI schemeによる画像の埋め込みを許可する", ->
    onLoad = jasmine.createSpy("onLoad")
    onError = jasmine.createSpy("onError")
    img = document.createElement("img")
    img.src = "data:image/gif;base64,R0lGODlhAQABAPAAAP///wAAACH5BAAAAAAALAAAAAABAAEAAAICRAEAOw=="
    img.addEventListener("load", onLoad)
    img.addEventListener("error", onError)
    document.body.appendChild(img)

    waitsFor -> onLoad.wasCalled

    runs ->
      expect(onLoad).toHaveBeenCalled()
      expect(onError).not.toHaveBeenCalled()
      document.body.removeChild(img)
      return
    return
  return
