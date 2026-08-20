// One shared Action Cable connection for the whole page, rather than
// every controller opening its own separate websocket. createConsumer
// figures out the right ws:// or wss:// URL on its own from the page
// it's loaded on, so nothing needs hardcoding here for dev vs.
// production.
import { createConsumer } from "@rails/actioncable"

export default createConsumer()
