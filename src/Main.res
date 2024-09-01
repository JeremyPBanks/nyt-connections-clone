%%raw("import './tailwind.css'")
%%raw(`import './main.css'`)

module GameLoader = {
  @react.component
  let make = () => {
    let (connections, slug): (Puzzle.connections, string) = ReactRouter.useLoaderData()
    <Game connections slug />
  }
}

module LoadValues = {
    @react.component
    let make = () => {
    let navigate = ReactRouter.useNavigate()
    Puzzle.sampleValues()->Puzzle.toConnections->Puzzle.Encode.slug->navigate(None)
    }
}

open ReactRouter

let router =
  <>
    <Route
      path="/"
      element={<GameLoader />}
      loader={({params}: loaderParams<{"slug": string}>) => {
        let slug = Puzzle.sampleValues()->Puzzle.toConnections->Puzzle.Encode.slug
        switch Puzzle.Decode.slug(slug) {
        | Ok(connections) => Data((connections, slug))
        | Error(e) => {
            Console.log3("Failed to decode slug: ", slug, e)
            ReactRouter.redirect("/")
          }
        }
      }}
    />
  </>
  ->createRoutesFromElements
  ->createHashRouter

ReactDOM.querySelector("#root")
->Option.getExn
->ReactDOM.Client.createRoot
->ReactDOM.Client.Root.render(
  <React.StrictMode>
    <div
      className="px-3 py-6 min-h-dscreen w-screen max-w-screen-sm mx-auto flex flex-col items-center justify-center">
      <RouterProvider router />
    </div>
  </React.StrictMode>,
)
