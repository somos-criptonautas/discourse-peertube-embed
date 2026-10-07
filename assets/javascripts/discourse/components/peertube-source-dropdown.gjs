import { i18n } from "discourse-i18n";
import ComboBox from "discourse/select-kit/components/combo-box";

const SOURCES = ["all", "community", "instance"];

function sources() {
  return SOURCES.map((id) => ({
    id,
    name: i18n(`peertube_embed.page.tab_${id}`),
  }));
}

// Todo / Comunidad / Instancia, styled like Discourse's category drop.
const PeertubeSourceDropdown = <template>
  <ComboBox
    @content={{(sources)}}
    @value={{@value}}
    @onChange={{@onChange}}
    class="peertube-source-dropdown"
  />
</template>;

export default PeertubeSourceDropdown;
