foam.CLASS({
  package: 'bench.notes',
  name: 'Note',

  documentation: `A note. Stored by noteDAO: an MDAO with a journal file in the
    embedded variant, a PostgresDAO (table "note") in the postgres variant.
    The sqlType values are used only by the PostgresDAO.`,

  properties: [
    {
      class: 'Long',
      name: 'id',
      sqlType: 'BIGINT'
    },
    {
      class: 'String',
      name: 'title',
      sqlType: 'TEXT'
    },
    {
      class: 'String',
      name: 'content',
      sqlType: 'TEXT'
    }
  ]
});
