/**
 * L'invitation en Worker, avec ses assets statiques.
 *
 * Le tableau de bord Cloudflare a créé un Worker « assets seuls » : il sert la
 * page, mais n'a aucun code, donc rien ne peut recevoir une réponse. Ce
 * fichier est ce code. Il garde exactement le même contrat que la version
 * Pages — `/api/etat`, `/api/reponse`, `/api/admin` — en appelant le même
 * `traiter()`. Tout le reste du trafic retombe sur les assets.
 */
import { traiter } from "../functions/api/[[route]].js";

export default {
  async fetch(request, env) {
    const { pathname } = new URL(request.url);
    if (pathname.startsWith("/api/"))
      return traiter(request, env, pathname.slice("/api/".length));
    // `ASSETS` est le binding déclaré dans wrangler.worker.toml : c'est lui
    // qui sert index.html et robots.txt, avec le cache de Cloudflare devant.
    return env.ASSETS.fetch(request);
  },
};
