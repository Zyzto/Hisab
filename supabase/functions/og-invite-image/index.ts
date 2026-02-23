import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { handler } from "./handler.tsx";

Deno.serve(handler);
