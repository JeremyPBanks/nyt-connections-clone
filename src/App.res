@react.component
let make = () => {
  open RescriptReactRouterDom.ReactRouterDOM

  <div className="p-3 w-screen max-w-screen-sm">
    <HashRouter>
      <Routes>
        <Route path="/" element={<Create />} />
        <Route path=":puzzle" element={<Game />} />
      </Routes>
    </HashRouter>
  </div>
}
