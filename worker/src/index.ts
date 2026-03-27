interface Env {
	BASETEN_API_KEY: string;
	APP_TOKEN: string;
}

const BASETEN_URL = "https://inference.baseten.co/v1/chat/completions";
const RATE_LIMIT_PER_MINUTE = 30;

// In-memory rate limiting (resets on worker restart, which is fine)
const rateLimits = new Map<string, { count: number; resetAt: number }>();

function isRateLimited(identifier: string): boolean {
	const now = Date.now();
	const entry = rateLimits.get(identifier);

	if (!entry || now > entry.resetAt) {
		rateLimits.set(identifier, { count: 1, resetAt: now + 60_000 });
		return false;
	}

	entry.count++;
	return entry.count > RATE_LIMIT_PER_MINUTE;
}

export default {
	async fetch(request: Request, env: Env): Promise<Response> {
		if (request.method === "OPTIONS") {
			return new Response(null, { status: 204 });
		}

		if (request.method !== "POST") {
			return new Response("Method not allowed", { status: 405 });
		}

		// Verify app token
		const auth = request.headers.get("Authorization");
		if (auth !== `Bearer ${env.APP_TOKEN}`) {
			return new Response("Unauthorized", { status: 401 });
		}

		// Rate limit by IP
		const ip = request.headers.get("CF-Connecting-IP") ?? "unknown";
		if (isRateLimited(ip)) {
			return new Response("Rate limited", { status: 429 });
		}

		// Forward to Baseten
		const body = await request.text();
		const basetenResponse = await fetch(BASETEN_URL, {
			method: "POST",
			headers: {
				"Content-Type": "application/json",
				Authorization: `Api-Key ${env.BASETEN_API_KEY}`,
			},
			body,
		});

		// Stream the response back
		return new Response(basetenResponse.body, {
			status: basetenResponse.status,
			headers: {
				"Content-Type":
					basetenResponse.headers.get("Content-Type") ??
					"application/json",
			},
		});
	},
};
