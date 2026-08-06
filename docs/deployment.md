# Deployment

De OpenShift-baseline is volledig declaratief en staat onder `deploy`. ArgoCD volgt de
`deploy/overlays/openshift`-overlay op `main` en synchroniseert die naar namespace `hkh`.

De backend, gebruikersfrontend, adminfrontend en PostgreSQL hebben eigen workloads, services,
probes en resourcegrenzen. Alleen de drie HTTP-services krijgen een OpenShift Route. De database
blijft intern en bewaart data op een PVC. De database gebruikt de SCL-org PostgreSQL 16-image die
voor OpenShift en willekeurige niet-root-UID's is ingericht; er is geen verruimde SCC nodig.

Runtimewaarden komen uit de SealedSecret `hkh-runtime`. Alleen de gitignored bronfile
`deploy/secrets-cluster.env` bevat plaintext; zie `deploy/README.md` voor generatie en installatie.

Image-tags beginnen op `main`. Na iedere componentbuild vervangt GitHub Actions uitsluitend de
bijbehorende tag door `sha-<commit>`, commit die manifestwijziging en laat ArgoCD de rollout doen.
