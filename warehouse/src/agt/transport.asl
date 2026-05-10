/*******************************************************************************
 * TRANSPORT - Agente que retira contenedores de la zona de salida.
 * Llamado por el scheduler al final de cada deadline.
 * Recibe la lista explícita de CIds a retirar para no depender de
 * beliefs globales que podrían no estar sincronizados.
 ******************************************************************************/

!start.

+!start <-
    .print("[Transport] Iniciado, en espera de retiradas").

/* El scheduler llama:
 *   .send(transport, achieve, pickup_for_transport(Group, ExitList))
 * ExitList es la lista de CIds confirmados en zona de salida para ese grupo.
 * Este plan se encarga de retirar todos los contenedores que ya han sido
 * depositados y confirmados por el scheduler. */
+!pickup_for_transport(Group, ExitList) <-
    .time(HH, MM, SS); .concat(HH, ":", MM, ":", SS, T);
    .length(ExitList, N);
    .print("[Transport] Retirando ", N, " contenedor(es) del grupo ", Group, " a las ", T);
    !retire_list(ExitList, Group);
    .send(scheduler, tell, transport_done(Group)).

/* Compatibilidad con llamadas antiguas sin lista (por si acaso).
 * El plan intenta retirar todos los contenedores en zona de salida si no
 * se proporciona una lista explícita desde el scheduler. */
+!pickup_for_transport(Group) <-
    .print("[Transport] Llamada sin lista para grupo ", Group, " — retirando por at_exit");
    !retire_all_by_percept;
    .send(scheduler, tell, transport_done(Group)).

/* Retirar los contenedores de la lista explícita */
+!retire_list([], _) <- true.
+!retire_list([CId | Rest], Group) <-
    .print("[Transport] Retirando: ", CId, " (grupo ", Group, ")");
    .send(scheduler, tell, transport_picked(CId));
    retire_from_exit(CId);
    !retire_list(Rest, Group).

/* Fallback: retirar todos los que estén en zona de salida por percept.
 * Se usa solo cuando no se dispone de una lista explícita de contenedores. */
+!retire_all_by_percept <-
    .findall(CId, at_exit(CId), L);
    .length(L, N);
    .print("[Transport] (Fallback) Retirados ", N, " contenedores de zona de salida");
    for (.member(CId, L)) {
        .send(scheduler, tell, transport_picked(CId));
        retire_from_exit(CId)
    }.

/* Recepción de notificación at_exit (informativo) */
+at_exit(CId)[source(_)] <-
    .print("[Transport] Notificado: ", CId, " en zona de salida").
