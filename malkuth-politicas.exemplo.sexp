(:malkuth-policy t
 :format-version 1
 :label "Políticas arquiteturais de exemplo"
 :rules
 ((:id "dominio-sem-ui"
   :type :forbid-dependency
   :severity :error
   :from "MEU-APP.DOMINIO*"
   :to "MEU-APP.UI*"
   :message "A camada de domínio não pode depender da interface.")
  (:id "aplicacao-usa-dominio"
   :type :require-dependency
   :severity :warning
   :from "MEU-APP.APLICACAO*"
   :to "MEU-APP.DOMINIO*")
  (:id "fanout-controlado"
   :type :max-fan-out
   :severity :warning
   :package "MEU-APP.*"
   :value 8)
  (:id "risco-local"
   :type :max-risk
   :severity :warning
   :package "MEU-APP.*"
   :value 45)
  (:id "dominio-sem-ciclos"
   :type :forbid-cycle
   :severity :error
   :package "MEU-APP.DOMINIO*")
  (:id "ordem-das-camadas"
   :type :layer-order
   :severity :error
   :layers ("MEU-APP.DOMINIO*"
            "MEU-APP.APLICACAO*"
            "MEU-APP.UI*"))))
