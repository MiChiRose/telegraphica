export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname !== "/v1/tdlib-config") {
      return new Response("Not found", { status: 404 });
    }

    if (request.method !== "GET") {
      return new Response("Method not allowed", { status: 405 });
    }

    const apiID = String(env.TELEGRAM_API_ID || "").trim();
    const apiHash = String(env.TELEGRAM_API_HASH || "").trim();
    if (!/^[1-9][0-9]*$/.test(apiID) || !/^[0-9a-fA-F]{32}$/.test(apiHash)) {
      return new Response("Server config is incomplete", { status: 503 });
    }

    const body = JSON.stringify({
      api_id: Number(apiID),
      api_hash: apiHash,
      tdlib_parameters_schema: "auto",
      use_test_dc: false,
      use_file_database: true,
      use_chat_info_database: true,
      use_message_database: true,
      use_secret_chats: false,
      enable_storage_optimizer: true,
      ignore_file_names: false
    });

    return new Response(body, {
      headers: {
        "content-type": "application/json; charset=utf-8",
        "cache-control": "no-store",
        "x-content-type-options": "nosniff"
      }
    });
  }
};
